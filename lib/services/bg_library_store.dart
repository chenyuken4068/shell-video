import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 背景库：全局导入的背景图（最多 20 张）
///
/// · 导入时把文件复制到应用私有目录，避免文件选择器的临时路径失效
/// · 存的是绝对路径列表（应用目录内），只保留仍然存在的文件
class BgLibraryStore {
  static const int maxCount = 20;
  static const String _indexName = 'bg_library.json';

  static Directory? _root;

  static Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'shell_video_app', 'bg_library'));
    await _root!.create(recursive: true);
    return _root!;
  }

  static Future<File> _file() async {
    final d = await _dir();
    return File(p.join(d.path, _indexName));
  }

  /// 读取背景列表（过滤掉已不存在的文件）
  static Future<List<String>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final j = jsonDecode(await f.readAsString());
      if (j is! List) return [];
      final out = <String>[];
      for (final e in j) {
        if (e is String && await File(e).exists()) out.add(e);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<String> list) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(list));
  }

  /// 导入一张背景：复制到应用目录并加入列表；返回 null 表示成功，否则是错误提示
  static Future<String?> importFile(String srcPath) async {
    final list = await load();
    if (list.length >= maxCount) return '最多只能导入 $maxCount 张背景';
    try {
      final d = await _dir();
      final ext = p.extension(srcPath);
      final name = 'bg_${DateTime.now().millisecondsSinceEpoch}$ext';
      final dst = File(p.join(d.path, name));
      await File(srcPath).copy(dst.path);
      list.add(dst.path);
      await _save(list);
      return null;
    } catch (e) {
      return '导入失败: $e';
    }
  }

  /// 删除一张背景（同时删文件）
  static Future<void> remove(String path) async {
    final list = await load();
    list.removeWhere((e) => e == path);
    await _save(list);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<void> clear() async {
    final list = await load();
    await _save([]);
    for (final e in list) {
      try {
        final f = File(e);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
