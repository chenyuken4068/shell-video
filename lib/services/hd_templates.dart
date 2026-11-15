import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/shell_template.dart';
import 'app_log.dart';

/// 高清模板（按需下载）里的单个配色
class HdColor {
  final String file;
  final int x, y, w, h, r;
  const HdColor(this.file, this.x, this.y, this.w, this.h, this.r);

  factory HdColor.fromJson(Map<String, dynamic> j) => HdColor(
        j['file'] as String,
        (j['x'] as num).toInt(),
        (j['y'] as num).toInt(),
        (j['w'] as num).toInt(),
        (j['h'] as num).toInt(),
        (j['r'] as num).toInt(),
      );
}

/// 高清模板里的一个机型
class HdModel {
  final String name;
  final String zip;
  final String sha256;
  final int size;
  final Map<String, HdColor> colors;
  const HdModel(this.name, this.zip, this.sha256, this.size, this.colors);

  factory HdModel.fromJson(Map<String, dynamic> j) => HdModel(
        (j['name'] as String?) ?? '',
        j['zip'] as String,
        (j['sha256'] as String?) ?? '',
        (j['size'] as num?)?.toInt() ?? 0,
        ((j['colors'] as Map?) ?? const {}).map((k, v) =>
            MapEntry(k as String, HdColor.fromJson((v as Map).cast<String, dynamic>()))),
      );
}

/// 高清模板下载器
///
/// 清单 `assets/hd_templates.json`（随 APK 打包）:
///   { repo, tag, models: { 机型key: {name, zip, sha256, size, colors: {模板id: {file,x,y,w,h,r}}} } }
///
/// zip 放在 GitHub Release 附件，按机型下载；下载后解压到
///   <documents>/hd_templates/<机型key>/<模板id>.png
class HdTemplates {
  HdTemplates._();

  /// 状态变化通知（下载进度 / 完成 / 删除）
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static final Map<String, HdModel> _models = {};
  static final Set<String> _downloaded = {};
  static final Map<String, double> _progress = {};
  static String _repo = '';
  static String _tag = '';
  static Directory? _root;
  static bool _inited = false;

  static Map<String, HdModel> get models => _models;

  /// 读清单 + 扫描已下载
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final raw = await rootBundleLoadString('assets/hd_templates.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _repo = (j['repo'] as String?) ?? 'chenyuken4068/shell-video';
      _tag = (j['tag'] as String?) ?? 'v3.3.5';
      final ms = (j['models'] as Map?) ?? const {};
      ms.forEach((k, v) {
        _models[k as String] = HdModel.fromJson((v as Map).cast<String, dynamic>());
      });
      final docs = await getApplicationDocumentsDirectory();
      _root = Directory(p.join(docs.path, 'hd_templates'));
      if (!await _root!.exists()) await _root!.create(recursive: true);
      await _rescan();
      AppLog.i('HdTemplates: ${_models.length} 个可下载机型，已下载 ${_downloaded.length} 个');
    } catch (e) {
      AppLog.i('HdTemplates init failed: $e');
    }
    tick.value++;
  }

  static Future<String> rootBundleLoadString(String key) async =>
      rootBundle.loadString(key);

  static Future<void> _rescan() async {
    _downloaded.clear();
    for (final key in _models.keys) {
      final dir = Directory(p.join(_root!.path, key));
      if (!await dir.exists()) continue;
      final m = _models[key]!;
      var ok = true;
      for (final c in m.colors.values) {
        if (!await File(p.join(dir.path, c.file)).exists()) {
          ok = false;
          break;
        }
      }
      if (ok) _downloaded.add(key);
    }
  }

  /// App 里模板 id 是 builtin_xxx，清单里是 xxx → 统一去掉前缀再查
  static String _norm(String id) =>
      id.startsWith('builtin_') ? id.substring(8) : id;

  /// 该模板 id 属于哪个可下载机型（没有则 null）
  static String? modelKeyOf(String? templateId) {
    if (templateId == null) return null;
    final id = _norm(templateId);
    for (final e in _models.entries) {
      if (e.value.colors.containsKey(id)) return e.key;
    }
    return null;
  }

  static HdModel? modelOf(String? templateId) {
    final k = modelKeyOf(templateId);
    return k == null ? null : _models[k];
  }

  static bool isDownloaded(String? templateId) {
    final k = modelKeyOf(templateId);
    return k != null && _downloaded.contains(k);
  }

  static double? progressOf(String? templateId) {
    final k = modelKeyOf(templateId);
    return k == null ? null : _progress[k];
  }

  /// 已下载的高清壳图路径（没有则 null）
  static String? casePathOf(String? templateId) {
    if (templateId == null || _root == null) return null;
    final k = modelKeyOf(templateId);
    if (k == null || !_downloaded.contains(k)) return null;
    final c = _models[k]!.colors[_norm(templateId)];
    if (c == null) return null;
    return p.join(_root!.path, k, c.file);
  }

  /// 用高清壳图 + 高清屏幕参数构造模板（供合成使用）
  static ShellTemplate? buildTemplate(String? templateId, [String? name]) {
    if (templateId == null) return null;
    final k = modelKeyOf(templateId);
    if (k == null) return null;
    final m = _models[k]!;
    final c = m.colors[_norm(templateId)];
    if (c == null) return null;
    final path = casePathOf(templateId);
    if (path == null) return null;
    final f = File(path);
    if (!f.existsSync()) return null;
    // 壳图尺寸：从 PNG 头读宽高
    final size = _pngSize(f);
    return ShellTemplate(
      id: templateId,
      name: name ?? m.name,
      casePath: path,
      caseWidth: size?.$1 ?? c.w * 2,
      caseHeight: size?.$2 ?? c.h * 2,
      screenX: c.x,
      screenY: c.y,
      screenW: c.w,
      screenH: c.h,
      cornerR: c.r,
      builtIn: true,
      isTransparent: false,
    );
  }

  /// 读 PNG 宽高（前 24 字节）
  static (int, int)? _pngSize(File f) {
    try {
      final b = f.openSync().readSync(24);
      f.openSync().closeSync();
      if (b.length < 24) return null;
      final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
      final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
      if (w <= 0 || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  /// 下载并解压某机型的高清模板；成功返回 true
  static Future<bool> download(String modelKey) async {
    final m = _models[modelKey];
    if (m == null || _root == null) return false;
    if (_progress.containsKey(modelKey)) return false;
    _progress[modelKey] = 0;
    tick.value++;
    final zipFile = File(p.join(_root!.path, '${modelKey}.zip'));
    try {
      final bytes = await _fetchWithFallback(m.zip, m.size, (got) {
        final total = m.size > 0 ? m.size : got;
        _progress[modelKey] =
            total <= 0 ? 0 : (got / total).clamp(0.0, 1.0).toDouble();
        tick.value++;
      });
      if (bytes == null) throw Exception('所有下载源都失败');
      if (m.size > 0 && bytes.length != m.size) {
        throw Exception('大小不符 ${bytes.length} != ${m.size}');
      }
      await zipFile.writeAsBytes(bytes, flush: true);
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final dir = Directory(p.join(_root!.path, modelKey));
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final name = p.basename(f.name);
        if (!name.endsWith('.png')) continue;
        await File(p.join(dir.path, name)).writeAsBytes(f.content as List<int>);
      }
      await zipFile.delete();
      _downloaded.add(modelKey);
      _progress.remove(modelKey);
      tick.value++;
      AppLog.i('HdTemplates: $modelKey 下载完成 ${(bytes.length / 1048576).toStringAsFixed(2)}MB');
      return true;
    } catch (e) {
      _progress.remove(modelKey);
      tick.value++;
      AppLog.i('HdTemplates 下载失败 $modelKey: $e');
      try {
        if (await zipFile.exists()) await zipFile.delete();
      } catch (_) {}
      return false;
    }
  }

  static Future<void> remove(String modelKey) async {
    if (_root == null) return;
    final dir = Directory(p.join(_root!.path, modelKey));
    if (await dir.exists()) await dir.delete(recursive: true);
    _downloaded.remove(modelKey);
    tick.value++;
  }

  /// 多源下载：gh-proxy 代理 → GitHub 直链
  static Future<Uint8List?> _fetchWithFallback(
      String zip, int expectSize, void Function(int got) onProgress) async {
    final raw =
        'https://raw.githubusercontent.com/$_repo/main/hd/$zip';
    final rel =
        'https://github.com/$_repo/releases/download/$_tag/$zip';
    // 优先仓库 raw（模板放代码仓库），再回退 Release 附件
    final urls = <String>[
      'https://gh-proxy.com/$raw',
      raw,
      'https://gh-proxy.com/$rel',
      rel,
    ];
    for (final u in urls) {
      try {
        final b = await _fetch(u, onProgress);
        if (b != null && b.isNotEmpty) return b;
      } catch (e) {
        AppLog.i('HdTemplates 源失败 $u: $e');
      }
    }
    return null;
  }

  static Future<Uint8List?> _fetch(
      String url, void Function(int got) onProgress) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'ShellVideoApp');
      req.headers.set('Accept', '*/*');
      final res = await req.close();
      if (res.statusCode != 200) {
        AppLog.i('HdTemplates HTTP ${res.statusCode}: $url');
        return null;
      }
      final total = res.contentLength > 0 ? res.contentLength : 0;
      final out = BytesBuilder(copy: false);
      var got = 0;
      await for (final chunk in res) {
        out.add(chunk);
        got += chunk.length;
        onProgress(total > 0 ? got : got);
        if (total > 0 && got > total + 1024) break;
      }
      final bytes = out.toBytes();
      if (total > 0 && bytes.length != total) {
        AppLog.i('HdTemplates 长度不符 ${bytes.length}/$total');
        return null;
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }
}
