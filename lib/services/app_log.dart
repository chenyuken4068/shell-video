import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 简易运行日志
/// · 安装后接管 debugPrint，并缓存最近 2000 行
/// · 可在「我的 → 日志抓取」导出 txt 并分享
class AppLog {
  static const int _max = 2000;
  static final List<String> _lines = [];
  static DebugPrintCallback? _old;
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    _old = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _old?.call(message, wrapWidth: wrapWidth);
      add(message);
    };
    add('===== AppLog 已安装 =====');
    add('平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  }

  /// 手动打点：直接进缓冲（release 包里 debugPrint 会被节流，不能只靠它）
  static void i(String message) {
    add('[壳映] $message');
    debugPrint('[壳映] $message');
  }

  static void add(String? message) {
    if (message == null || message.isEmpty) return;
    final t = DateTime.now();
    final ts = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
    if (_lines.length >= _max) _lines.removeAt(0);
    _lines.add('$ts  $message');
  }

  static int get lineCount => _lines.length;

  /// 导出成 txt，返回文件路径
  static Future<String> exportToFile() async {
    // 用缓存目录：微信/QQ 分享时通过 FileProvider 可读
    final docs = await getTemporaryDirectory();
    final dir = Directory(p.join(docs.path, 'logs'));
    await dir.create(recursive: true);
    final now = DateTime.now();
    final name = 'log_${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.txt';
    final f = File(p.join(dir.path, name));
    await f.writeAsString(_lines.join('\n'), flush: true);
    return f.path;
  }

  /// 导出并调起分享
  static Future<void> exportAndShare(BuildContext context) async {
    try {
      final path = await exportToFile();
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'text/plain', name: p.basename(path))],
          text: '壳映运行日志（${_lines.length} 行）',
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已生成：$path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志导出失败: $e')),
      );
    }
  }
}
