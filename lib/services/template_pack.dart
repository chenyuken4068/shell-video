import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/shell_template.dart';
import 'template_store.dart';

/// 模板分享包（`.zip`，内容就是 template.json + case.png）：
///   template.json  ← 名字 / 图宽高 / 标定框 / 圆角R / 是否透明 / 格式版本
///   case.png       ← 壳图原图（不改尺寸，避免标定坐标错位）
///
/// 用法：
///   - 导出分享：`TemplatePack.write(t, outPath)` → share_plus / file_picker.saveFile
///   - 导入：`TemplatePack.parse(packPath, workDir: ...)` 先校验+预览，再 `importInto`
class TemplatePack {
  static const int formatVersion = 1;
  static const int maxPackBytes = 20 * 1024 * 1024; // 20MB
  static const int maxImageBytes = 12 * 1024 * 1024; // 12MB
  static const int maxSide = 5000; // 长边像素上限
  static const String jsonName = 'template.json';
  static const String imageName = 'case.png';
  /// 分享包后缀：用标准 zip（微信等 App 只认常见类型，未知后缀会收发失败）
  static const String ext = 'zip';
  /// 早期版本用过的后缀，导入端仍然兼容
  static const List<String> legacyExts = ['shtpl'];

  /// 打包模板 → 写出 `.shtpl`
  static Future<String> write(ShellTemplate t, String outPath) async {
    final imgBytes = await File(t.casePath).readAsBytes();
    final meta = <String, dynamic>{
      'format': formatVersion,
      'kind': 'shell_template',
      'name': t.name,
      'caseWidth': t.caseWidth,
      'caseHeight': t.caseHeight,
      'screenX': t.screenX,
      'screenY': t.screenY,
      'screenW': t.screenW,
      'screenH': t.screenH,
      'cornerR': t.cornerR,
      'isTransparent': t.isTransparent,
      'image': imageName,
      'app': 'shell_video_app',
    };
    final jsonBytes = utf8.encode(jsonEncode(meta));
    final archive = Archive()
      ..addFile(ArchiveFile(jsonName, jsonBytes.length, jsonBytes))
      ..addFile(ArchiveFile(imageName, imgBytes.length, imgBytes));
    final zipped = ZipEncoder().encode(archive);
    final out = File(outPath);
    await out.parent.create(recursive: true);
    await out.writeAsBytes(zipped);
    return outPath;
  }

  /// 校验并解析（不写库）：失败抛 [TemplatePackException]，消息可直接弹给用户
  static Future<TemplatePackData> parse(
    String packPath, {
    required String workDir,
  }) async {
    final f = File(packPath);
    if (!await f.exists()) throw TemplatePackException('文件不存在');
    final len = await f.length();
    if (len <= 0) throw TemplatePackException('文件是空的');
    if (len > maxPackBytes) {
      throw TemplatePackException('文件太大（${(len / 1048576).toStringAsFixed(1)}MB，上限 20MB）');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await f.readAsBytes());
    } catch (_) {
      throw TemplatePackException('不是有效的模板文件（解析失败）');
    }

    Map<String, dynamic>? meta;
    Uint8List? imageBytes;
    var imageEntryCount = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = p.basename(entry.name);
      if (name == jsonName) {
        final bytes = entry.content;
        try {
          final j = jsonDecode(utf8.decode(bytes));
          if (j is Map<String, dynamic>) meta = j;
        } catch (_) {
          throw TemplatePackException('模板信息损坏（json 解析失败）');
        }
      } else {
        // 包内只允许一张图；防止夹带其它文件
        imageEntryCount++;
        if (imageEntryCount > 1) throw TemplatePackException('包里图片不止一张，已拒绝');
        if (entry.size > maxImageBytes) {
          throw TemplatePackException('壳图太大（上限 12MB）');
        }
        imageBytes = entry.content;
      }
    }
    if (meta == null) throw TemplatePackException('请导入正确的模板包');
    if (imageBytes == null || imageBytes.isEmpty) {
      throw TemplatePackException('缺少壳图 case.png');
    }
    final format = (meta['format'] as num?)?.toInt() ?? 0;
    if (format != formatVersion) {
      throw TemplatePackException('模板格式版本不支持（v$format，当前支持 v$formatVersion）');
    }

    // 真实宽高以图片为准（自愈：包里的数字可能与图不符）
    final size = await compute(_imageSizeOf, imageBytes);
    final realW = size[0], realH = size[1];
    if (realW <= 0 || realH <= 0) throw TemplatePackException('壳图无法解码');
    if (realW > maxSide || realH > maxSide) {
      throw TemplatePackException('壳图尺寸过大（$realW×$realH，上限 $maxSide）');
    }

    var sx = (meta['screenX'] as num?)?.toInt() ?? 0;
    var sy = (meta['screenY'] as num?)?.toInt() ?? 0;
    var sw = (meta['screenW'] as num?)?.toInt() ?? 0;
    var sh = (meta['screenH'] as num?)?.toInt() ?? 0;
    if (sw <= 0 || sh <= 0) throw TemplatePackException('屏幕框参数无效');
    // 越界就夹回图内（宽容处理，避免因为几像素误差拒绝）
    sx = sx.clamp(0, realW - 1);
    sy = sy.clamp(0, realH - 1);
    sw = sw.clamp(1, realW - sx);
    sh = sh.clamp(1, realH - sy);
    var r = (meta['cornerR'] as num?)?.toInt() ?? 0;
    r = r.clamp(0, (sw < sh ? sw : sh) ~/ 2);

    final name = (meta['name'] as String?)?.trim();
    final safeName = _safeName(name == null || name.isEmpty ? '导入模板' : name);

    final outDir = Directory(workDir);
    await outDir.create(recursive: true);
    final imgPath = p.join(outDir.path, '$_tmpPrefix${DateTime.now().millisecondsSinceEpoch}.png');
    await File(imgPath).writeAsBytes(imageBytes);

    return TemplatePackData(
      name: safeName,
      imagePath: imgPath,
      caseWidth: realW,
      caseHeight: realH,
      screenX: sx,
      screenY: sy,
      screenW: sw,
      screenH: sh,
      cornerR: r,
      isTransparent: meta['isTransparent'] == true,
    );
  }

  /// 解析 + 写入模板库（重名自动加序号），返回新模板
  static Future<ShellTemplate> importInto(
    String packPath, {
    required TemplateStore store,
    required String workDir,
  }) async {
    final data = await parse(packPath, workDir: workDir);
    final name = await uniqueName(data.name, store);
    return store.save(
      name: name,
      srcImage: data.imagePath,
      caseWidth: data.caseWidth,
      caseHeight: data.caseHeight,
      screenX: data.screenX,
      screenY: data.screenY,
      screenW: data.screenW,
      screenH: data.screenH,
      cornerR: data.cornerR,
      isTransparent: data.isTransparent,
    );
  }

  /// 重名自动加序号：小明的壳 → 小明的壳 (2) → (3) …
  static Future<String> uniqueName(String base, TemplateStore store) async {
    final names = (await store.load()).map((e) => e.name).toSet();
    if (!names.contains(base)) return base;
    for (var i = 2; i < 999; i++) {
      final cand = '$base ($i)';
      if (!names.contains(cand)) return cand;
    }
    return '$base (${DateTime.now().millisecondsSinceEpoch % 1000})';
  }

  static const String _tmpPrefix = 'pack_';

  /// 去掉路径分隔符等危险字符，限制长度
  static String _safeName(String raw) {
    var s = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (s.length > 40) s = s.substring(0, 40);
    if (s.isEmpty) s = '导入模板';
    return s;
  }

  static List<int> _imageSizeOf(Uint8List bytes) {
    try {
      final im = img.decodeImage(bytes);
      if (im == null) return <int>[0, 0];
      return <int>[im.width, im.height];
    } catch (_) {
      return <int>[0, 0];
    }
  }
}

/// 解析结果（未写库）
class TemplatePackData {
  final String name;
  final String imagePath;
  final int caseWidth;
  final int caseHeight;
  final int screenX;
  final int screenY;
  final int screenW;
  final int screenH;
  final int cornerR;
  final bool isTransparent;

  const TemplatePackData({
    required this.name,
    required this.imagePath,
    required this.caseWidth,
    required this.caseHeight,
    required this.screenX,
    required this.screenY,
    required this.screenW,
    required this.screenH,
    required this.cornerR,
    required this.isTransparent,
  });

  String get sizeLabel => '$caseWidth×$caseHeight';
  String get screenLabel => '$screenW×$screenH  @($screenX,$screenY)';
}

class TemplatePackException implements Exception {
  final String message;
  const TemplatePackException(this.message);
  @override
  String toString() => message;
}
