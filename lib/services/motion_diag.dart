import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 动图（Motion Photo / 实况照片）诊断器
///
/// 作用：把一个 `.jpg` 实况照片拆开，逐项对照
///  ① Android 官方 Motion Photo 1.0 规范
///  ② 酷安实测可用的真机产物结构
/// 输出一份纯文本报告（txt），便于用户导出后反馈。
class MotionDiag {
  MotionDiag._();

  /// 允许的视频编码（Google Motion Photo 1.0 只允许这三种）
  static const allowedCodecs = {'avc1', 'hvc1', 'hev1', 'av01'};

  /// 解析期间发现 avcC level=0（严格解码器可能拒绝）
  static bool _warnLevel = false;

  static Future<String> run(String path, {String extra = ''}) async {
    final f = File(path);
    if (!await f.exists()) return '文件不存在: $path';
    final data = await f.readAsBytes();
    return analyzeBytes(data, path: path, extra: extra);
  }

  static String analyzeBytes(Uint8List data, {String path = '', String extra = ''}) {
    _warnLevel = false;
    final size = data.length;
    final b = StringBuffer();
    final ok = <String>[];
    final bad = <String>[];
    final warn = <String>[];

    b.writeln('壳映 ShellVideo · 动图诊断报告');
    b.writeln('生成时间: ${DateTime.now().toString().substring(0, 19)}');
    b.writeln('文件: $path');
    b.writeln('大小: $size 字节 (${(size / 1048576).toStringAsFixed(2)} MB)');
    if (extra.isNotEmpty) {
      b.writeln();
      b.writeln('=== 导出上下文 ===');
      b.writeln(extra);
    }

    // ───────── ① JPEG 段 ─────────
    b.writeln();
    b.writeln('=== ① JPEG 段结构 ===');
    final segs = <String>[];
    int? primaryEoi; // 主图 JPEG 结束位置（EOI 之后）
    var i = 2;
    var primaryEnd = -1;
    while (i + 4 <= size) {
      if (data[i] != 0xFF) break;
      final marker = data[i + 1];
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      if (marker == 0xD9) {
        primaryEnd = i + 2;
        break;
      }
      final segLen = (data[i + 2] << 8) | data[i + 3];
      if (segLen < 2 || i + 2 + segLen > size) break;
      final segStart = i;
      final body = data.sublist(i + 4, i + 2 + segLen);
      var name = 'FF${marker.toRadixString(16).toUpperCase().padLeft(2, '0')}';
      if (marker == 0xE0) name += ' APP0(JFIF)';
      if (marker == 0xE1) {
        if (_startsWith(body, ascii.encode('http://ns.adobe.com/xap/1.0/'))) {
          name += ' APP1(XMP)';
        } else if (_startsWith(body, ascii.encode('Exif'))) {
          name += ' APP1(Exif)';
        } else {
          name += ' APP1(其他)';
        }
      }
      if (marker == 0xFE) name += ' COM';
      segs.add('  $name  len=$segLen  @$segStart');
      if (marker == 0xDA) {
        // SOS：图像数据开始，向后找 EOI（JPEG 熵编码里 FF 都会被转义成 FF00，FFD9 不会误判）
        var j = i + 2 + segLen;
        var found = -1;
        while (j + 1 < size) {
          if (data[j] == 0xFF && data[j + 1] == 0xD9) {
            found = j + 2;
            break;
          }
          j++;
        }
        primaryEnd = found;
        break;
      }
      i += 2 + segLen;
    }
    segs.forEach(b.writeln);
    b.writeln('  主图 JPEG 结束(EOI 之后): $primaryEnd');

    // XMP
    final xmpStart = _indexOf(data, ascii.encode('http://ns.adobe.com/xap/1.0/'));
    var xmpText = '';
    if (xmpStart >= 0) {
      final segLen = (data[xmpStart - 4] << 8) | data[xmpStart - 3];
      final end = (xmpStart + segLen - 4).clamp(0, size);
      xmpText = utf8.decode(data.sublist(xmpStart, end), allowMalformed: true);
    }

    // ───────── ② XMP 关键字段 ─────────
    b.writeln();
    b.writeln('=== ② XMP 关键字段 ===');
    if (xmpText.isEmpty) {
      b.writeln('  ✗ 没有找到 XMP');
      bad.add('缺少 XMP');
    } else {
      const keys = [
        'GCamera', 'MotionPhoto', 'MotionPhotoVersion',
        'MotionPhotoPresentationTimestampUs', 'MicroVideo', 'MicroVideoOffset',
        'OpCamera', 'MotionPhotoOwner', 'OLivePhotoVersion', 'VideoLength',
        'hdrgm', 'Container', 'Item',
      ];
      final found = <String>[];
      for (final k in keys) {
        if (xmpText.contains(k)) found.add(k);
      }
      b.writeln('  包含: ${found.join(', ')}');
      for (final m in RegExp(r'(?:GCamera|OpCamera|hdrgm):(\w+)="([^"]*)"')
          .allMatches(xmpText)) {
        b.writeln('  ${m.group(1)} = ${m.group(2)}');
      }
      if (xmpText.contains('MotionPhoto="1"') ||
          xmpText.contains('MotionPhoto="true"')) {
        ok.add('XMP 声明了动态照片 (GCamera:MotionPhoto=1)');
      } else {
        bad.add('XMP 没有 GCamera:MotionPhoto=1（第三方不会当动图）');
      }
    }

    // ───────── ③ Container 容器项 ─────────
    b.writeln();
    b.writeln('=== ③ Container:Directory 容器项 ===');
    final items = <Map<String, String>>[];
    if (xmpText.isNotEmpty) {
      final dirIdx = xmpText.indexOf('Container:Directory');
      final dir = dirIdx >= 0 ? xmpText.substring(dirIdx) : '';
      for (final li in RegExp(r'<rdf:li[\s\S]*?</rdf:li>').allMatches(dir)) {
        final chunk = li.group(0)!;
        final m = RegExp(r'Item:(Mime|Semantic|Length|Padding)="([^"]*)"')
            .allMatches(chunk);
        final item = <String, String>{};
        for (final x in m) {
          item[x.group(1)!] = x.group(2)!;
        }
        if (item.isNotEmpty) items.add(item);
      }
    }
    if (items.isEmpty) {
      b.writeln('  ✗ 没有 Container 项');
      bad.add('缺少 Container:Directory');
    } else {
      for (var k = 0; k < items.length; k++) {
        final it = items[k];
        b.writeln('  [$k] Mime=${it['Mime']} Semantic=${it['Semantic']} '
            'Length=${it['Length']} Padding=${it['Padding']}');
      }
      final primaries = items.where((e) => e['Semantic'] == 'Primary').length;
      final motion = items.where((e) => e['Semantic'] == 'MotionPhoto').length;
      if (primaries == 1) {
        ok.add('Container 第一个项是 Primary');
      } else {
        bad.add('Primary 项数量=$primaries（规范要求恰好 1 个）');
      }
      if (motion == 1) {
        ok.add('MotionPhoto 容器项恰好 1 个');
      } else {
        bad.add('MotionPhoto 项数量=$motion（规范要求恰好 1 个）');
      }
      if (items.length > 1 && (items[0]['Padding'] ?? '0') != '0') {
        warn.add('主图有 Padding=${items[0]['Padding']}');
      }
      for (var k = 1; k < items.length; k++) {
        if ((items[k]['Padding'] ?? '0') != '0') {
          warn.add('第 $k 项有 Padding（规范只允许主图带 Padding）');
        }
      }
    }

    // ───────── ④ MP4 定位 ─────────
    b.writeln();
    b.writeln('=== ④ 内嵌 MP4 ===');
    final ftypIdx = _indexOf(data, ascii.encode('ftyp'), from: primaryEnd > 0 ? primaryEnd : 0);
    int mp4Offset = ftypIdx >= 0 ? ftypIdx - 4 : -1;
    final motionItem = items.where((e) => e['Semantic'] == 'MotionPhoto').toList();
    int? declaredLen;
    if (motionItem.isNotEmpty) {
      declaredLen = int.tryParse(motionItem.first['Length'] ?? '');
    }
    final tailLen = mp4Offset > 0 ? size - mp4Offset : -1;
    b.writeln('  实际起点: $mp4Offset   实际长度: $tailLen');
    b.writeln('  XMP 声明 MotionPhoto Length: $declaredLen');
    if (mp4Offset > 0) {
      if (declaredLen != null && declaredLen == tailLen) {
        ok.add('MotionPhoto Length 与实际长度一致');
      } else {
        bad.add('MotionPhoto Length($declaredLen) ≠ 实际($tailLen)');
      }
      if (primaryEnd > 0 && mp4Offset > primaryEnd) {
        final gap = mp4Offset - primaryEnd;
        b.writeln('  主图结束 → MP4 起点之间的字节数: $gap');
        if (gap > 0) {
          final gapIdx = _indexOf(data, ascii.encode('GainMap'), from: primaryEnd);
          warn.add('主图与 MP4 之间有 $gap 字节（可能是 GainMap 图像，'
              '${gapIdx >= 0 ? "XMP 里有 GainMap?" : "酷安/多数解析器会从这里当成视频开头 ✗"}）');
        }
      }
    } else {
      b.writeln('  ✗ 没有找到 ftyp（没有内嵌 MP4）');
      bad.add('没有内嵌 MP4');
    }

    // 解析 MP4 box
    String? codec;
    int? vw, vh;
    final topBoxes = <String>[];
    final boxLines = <String>[];
    if (mp4Offset > 0) {
      final r = _parseMp4(data, mp4Offset);
      topBoxes.addAll(r.$1);
      boxLines.addAll(r.$2);
      codec = r.$3;
      vw = r.$4;
      vh = r.$5;
      for (final line in boxLines) {
        b.writeln(line);
      }
      b.writeln('  视频编码: $codec');
      if (vw != null && vh != null) b.writeln('  分辨率: ${vw}x$vh');
      if (codec == null) {
        bad.add('解析不到视频轨');
      } else if (allowedCodecs.contains(codec)) {
        ok.add('视频编码 $codec 在规范允许范围（AVC/HEVC/AV1）');
      } else {
        bad.add('视频编码 $codec 不在规范允许范围（只允许 AVC/HEVC/AV1）'
            ' → 酷安会 setDataSource failed 0x80000000');
      }
      final moovFirst =
          topBoxes.contains('moov') && topBoxes.contains('mdat') &&
          topBoxes.indexOf('moov') < topBoxes.indexOf('mdat');
      if (moovFirst) {
        ok.add('moov 在 mdat 之前（faststart ✓）');
      } else {
        warn.add('moov 不在 mdat 之前（部分解析器需要 faststart）');
      }
      if (vw != null && vh != null && (vw.isOdd || vh.isOdd)) {
        warn.add('视频宽高有奇数（${vw}x$vh），部分解码器会失败');
      }
    }

    // ───────── ⑤ 结论 ─────────
    b.writeln();
    b.writeln('=== ⑤ 结论 ===');
    for (final x in ok) {
      b.writeln('  ✓ $x');
    }
    for (final x in warn) {
      b.writeln('  ! $x');
    }
    for (final x in bad) {
      b.writeln('  ✗ $x');
    }
    b.writeln();
    if (bad.isEmpty) {
      b.writeln('结论: 通过 ✓ 符合 Android Motion Photo 1.0 / 酷安要求');
    } else {
      b.writeln('结论: 不通过 ✗ 共 ${bad.length} 项不符合要求（见上）');
    }
    return b.toString();
  }

  // ───────────── helpers ─────────────

  static int _indexOf(Uint8List d, List<int> pat, {int from = 0}) {
    outer:
    for (var i = from; i + pat.length <= d.length; i++) {
      for (var k = 0; k < pat.length; k++) {
        if (d[i + k] != pat[k]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static bool _startsWith(List<int> a, List<int> b) {
    if (a.length < b.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 解析 MP4 顶层 box 顺序 + 采样条目（视频编码、分辨率）
  static (List<String>, List<String>, String?, int?, int?) _parseMp4(
      Uint8List d, int start) {
    final top = <String>[];
    final lines = <String>[];
    String? codec;
    int? w, h;

    void walk(int from, int to, int depth) {
      var i = from;
      while (i + 8 <= to && i + 8 <= d.length) {
        final size = (d[i] << 24) | (d[i + 1] << 16) | (d[i + 2] << 8) | d[i + 3];
        final type = String.fromCharCodes(d.sublist(i + 4, i + 8));
        if (size < 8 || i + size > to) break;
        if (depth == 0) {
          top.add(type);
          lines.add('  [$type] size=$size @${i - start}');
        } else if (depth == 1) {
          lines.add('    $type ($size)');
        }
        const container = {
          'moov', 'trak', 'mdia', 'minf', 'stbl', 'stsd',
          'edts', 'dinf', 'udta', 'mvex', 'moof', 'traf',
        };
        if (container.contains(type)) {
          walk(i + 8, i + size, depth + 1);
        }
        if (type == 'stsd') {
          final p = i + 16; // version/flags + entry_count
          if (p + 8 <= i + size) {
            final esize = (d[p] << 24) | (d[p + 1] << 16) | (d[p + 2] << 8) | d[p + 3];
            final etype = String.fromCharCodes(d.sublist(p + 4, p + 8));
            lines.add('      SAMPLE=$etype size=$esize');
            if (etype == 'avc1' || etype == 'hvc1' || etype == 'hev1' ||
                etype == 'mp4v' || etype == 'av01' || etype == 'vp09') {
              if (codec == null) {
                codec = etype;
                final base = p;
                if (base + 36 <= d.length) {
                  w = (d[base + 32] << 8) | d[base + 33];
                  h = (d[base + 34] << 8) | d[base + 35];
                }
                // avcC 里的 profile/level
                final avcC = _indexOf(d.sublist(0, (i + size).clamp(0, d.length)),
                    ascii.encode('avcC'), from: p);
                if (avcC > 0 && avcC + 8 < d.length) {
                  // avcC 结构：size(4) 'avcC'(4) version(1) profile(1) compat(1) level(1)
                  final ver = d[avcC + 4];
                  final prof = d[avcC + 5];
                  final compat = d[avcC + 6];
                  final lvl = d[avcC + 7];
                  const profName = {
                    66: 'Baseline',
                    77: 'Main',
                    88: 'Extended',
                    100: 'High'
                  };
                  final lvlName =
                      lvl == 0 ? '未标注(0)' : (lvl / 10).toStringAsFixed(1);
                  lines.add('      avcC version=$ver '
                      'profile=$prof(${profName[prof] ?? "?"}) '
                      'compat=$compat level=$lvl($lvlName)');
                  if (lvl == 0) _warnLevel = true;
                }
              }
            }
          }
        }
        i += size;
      }
    }

    walk(start, d.length.clamp(0, d.length), 0);
    lines.add('  顶层 box 顺序: ${top.join(' → ')}');
    return (top, lines, codec, w, h);
  }
}
