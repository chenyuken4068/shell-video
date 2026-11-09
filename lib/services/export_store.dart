import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 一条导出记录（图库展示用）
class ExportItem {
  final String id;
  final String name; // 视频名
  final String path; // 文件绝对路径
  final String resLabel; // 分辨率标签 4K/1080P/720P
  final String timeLabel; // 今天 09:12 之类
  final String durLabel; // 时长 00:06
  final String type; // video / shot

  const ExportItem({
    required this.id,
    required this.name,
    required this.path,
    required this.resLabel,
    required this.timeLabel,
    required this.durLabel,
    this.type = 'video',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'resLabel': resLabel,
        'timeLabel': timeLabel,
        'durLabel': durLabel,
        'type': type,
      };

  factory ExportItem.fromJson(Map<String, dynamic> j) => ExportItem(
        id: j['id'] as String,
        name: j['name'] as String,
        path: j['path'] as String,
        resLabel: j['resLabel'] as String,
        timeLabel: j['timeLabel'] as String,
        durLabel: j['durLabel'] as String,
        type: j['type'] as String? ?? 'video',
      );
}

/// 导出记录存储：图库数据源（应用私有目录 JSON）
class ExportStore {
  static const _indexName = 'exports.json';

  Directory? _root;

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'shell_video_app'));
    await _root!.create(recursive: true);
    return _root!;
  }

  Future<List<ExportItem>> load() async {
    final root = await _dir();
    final f = File(p.join(root.path, _indexName));
    if (!await f.exists()) return [];
    try {
      final data = jsonDecode(await f.readAsString());
      final list = <ExportItem>[];
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) {
            final it = ExportItem.fromJson(e);
            if (await File(it.path).exists()) list.add(it);
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 追加一条记录（新导出放最前）
  Future<void> add(ExportItem item) async {
    final root = await _dir();
    final f = File(p.join(root.path, _indexName));
    final list = await load();
    list.insert(0, item);
    await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> remove(String id) async {
    final root = await _dir();
    final f = File(p.join(root.path, _indexName));
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// 导出目录（视频文件落盘位置）
  Future<Directory> outputsDir() async {
    final root = await _dir();
    final d = Directory(p.join(root.path, 'outputs'));
    await d.create(recursive: true);
    return d;
  }
}
