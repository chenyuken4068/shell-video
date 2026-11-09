import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 解析「动态照片」文件，输出可复制的字段报告（纯 Dart，无依赖）
/// 解析内容：XMP 原文/长度、JPEG 结束位置、尾部 MP4 结构（ftyp/moov/mdat/avc1/mp4a）
String probeMotionPhoto(Uint8List d, String name) {
  final sb = StringBuffer();
  sb.writeln('=== $name ===');
  sb.writeln('大小: ${d.length} 字节');
  final isJpeg = d.length > 2 && d[0] == 0xFF && d[1] == 0xD8;
  sb.writeln('是否JPEG: $isJpeg');

  // ── XMP（在 JPEG 的 APP1 段里）──
  final s = utf8.decode(d, allowMalformed: true);
  final i = s.indexOf('<x:xmpmeta');
  final j = s.indexOf('</x:xmpmeta>');
  if (i >= 0 && j > i) {
    sb.writeln('XMP长度: ${j - i + 12}');
    sb.writeln('--- XMP 原文 ---');
    sb.writeln(s.substring(i, j + 12));
  } else {
    sb.writeln('XMP: 未找到（可能字段在 MakerNote / 其它段）');
  }

  // ── JPEG 结束位置（从后往前找 FFD9）──
  var eoi = -1;
  for (var k = d.length - 4; k >= 0; k--) {
    if (d[k] == 0xFF && d[k + 1] == 0xD9) {
      eoi = k + 2;
      break;
    }
  }
  sb.writeln('JPEG结束位置: ${eoi >= 0 ? eoi : '未找到'}');

  // ── 尾部 MP4 ──
  if (eoi > 0 && eoi < d.length - 8) {
    final tail = d.sublist(eoi);
    sb.writeln('尾部大小: ${tail.length} 字节');
    final head = tail
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    sb.writeln('尾部开头8字节: $head');
    final t = utf8.decode(tail, allowMalformed: true);
    final mo = t.indexOf('moov');
    final md = t.indexOf('mdat');
    sb.writeln('含ftyp: ${t.contains('ftyp')}');
    sb.writeln('含moov: ${mo >= 0} | moov在前: ${mo >= 0 && md >= 0 && mo < md}');
    sb.writeln('含avc1(H.264): ${t.contains('avc1')} | 含mp4a(音频): ${t.contains('mp4a')}');
  } else {
    sb.writeln('尾部MP4: 无（可能不是"拼在尾部"的格式）');
  }
  return sb.toString();
}

/// 找到动态照片里内嵌 MP4 的起始偏移（JPEG 的 FFD9 之后紧跟 ftyp/moov/mdat）
int findMotionVideoStart(Uint8List d) {
  for (var i = 0; i + 12 < d.length; i++) {
    if (d[i] == 0xFF && d[i + 1] == 0xD9) {
      final head = String.fromCharCodes(d.sublist(i + 2, i + 14));
      if (head.contains('ftyp') || head.contains('moov') || head.contains('mdat')) {
        return i + 2;
      }
    }
  }
  return -1;
}

/// 从动态照片（JPEG+MP4）抽出内嵌视频写到 outPath
/// 返回写入字节数；0 = 不是动态照片 / 没有视频
Future<int> extractMotionVideo(String jpegPath, String outPath) async {
  final d = await File(jpegPath).readAsBytes();
  final s = findMotionVideoStart(d);
  if (s < 0) return 0;
  final mp4 = d.sublist(s);
  if (mp4.length < 1024) return 0;
  await File(outPath).writeAsBytes(mp4, flush: true);
  return mp4.length;
}
