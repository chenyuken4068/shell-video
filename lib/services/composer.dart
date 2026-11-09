import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';

import '../models/shell_template.dart';
import 'corner_mask.dart';
import 'image_utils.dart';
import 'video_info.dart';

/// 输出画质档位
enum Quality { original, p1080, p720 }

/// FFmpeg 合成引擎：视频合入手机壳
class Composer {
  /// 合成带壳视频
  /// [onProgress] 0.0 ~ 1.0
  /// [ratio] 屏占比：屏幕占成品画布比例（<1 时画布=屏幕/ratio 四周留白，默认 1=原壳尺寸）
  /// [canvasRatio] 画布宽高比（如 9/16、16/9、3/4、4/3、1/1.414、1.414/1；0=按屏占比自然比例）
  /// [bgImagePath] 背景图（等比 cover 铺画布，可缩放/偏移）；为空时用 [background] 纯色
  static Future<void> composeVideo({
    required ShellTemplate template,
    required String videoPath,
    required VideoInfo info,
    required String outputPath,
    String background = 'white',
    bool hardware = false,
    bool landscape = false,
    Quality quality = Quality.original,
    /// 导出帧率；0 = 用视频探测帧率
    int fpsOverride = 0,
    double ratio = 1.0,
    double canvasRatio = 0,
    String? bgImagePath,
    /// 背景高斯模糊开关与强度（sigma 2~40）
    bool bgBlur = false,
    double bgBlurSigma = 18,
    double bgScale = 1.0,
    double bgDx = 0,
    double bgDy = 0,
    void Function(double progress, String speed)? onProgress,
    void Function(String log)? onLog,
    double shellDx = 0,
  double shellDy = 0,
  /// 内容旋转 90° 次数：1=顺时针，3=逆时针（0=不转）
  int contentQuarterTurns = 0,
}) async {
    // 视频合成：R 角裁切（贴合壳圆角防裸露）+ 画面四边各裁 2px 去边缘绿线
    final maskPath = await CornerMask.ensure(
        template.screenW, template.screenH, template.cornerR);

    final bgColor = background == 'white' ? 'white' : 'black';
    final duration = info.durationSeconds.isFinite && info.durationSeconds > 0
        ? info.durationSeconds
        : 60.0;
    final fps = fpsOverride > 0
        ? fpsOverride.toDouble()
        : (info.fps.isFinite && info.fps > 0 && info.fps <= 240
            ? info.fps
            : 30.0);

    final scaleQuality = switch (quality) {
      Quality.original => 'trunc(iw/2)*2:trunc(ih/2)*2',
      Quality.p1080 => '-2:1920',
      Quality.p720 => '-2:1280',
    };

    // 画布：默认 = 壳图 + 四周各扩短边1%（合计2%）外扩区背景色；
    // 屏占比模式 = 屏幕/ratio（≥壳尺寸），壳在画布内居中
    // 画布 = 壳框 ÷ 缩放 × 110%；壳框 = 屏幕框每边外扩「屏幕框宽 × 6%」
    // （ratio = 设计壳缩放 25%~100%：100% 时壳占画布 91%，四周留 10% 余量不会出框）
    final shellPad = (template.screenW * 0.06).round();
    final shellW = template.screenW + shellPad * 2;
    final shellH = template.screenH + shellPad * 2;
    var cw, ch, ccx, ccy;
    {
      var bw = shellW / ratio * 1.1;
      var bh = shellH / ratio * 1.1;
      // 画布比例：横屏取倒数（9:16 → 16:9）
      final cr = _canvasRatioFor(template, canvasRatio);
      if (cr > 0) {
        if (bw / bh > cr) {
          bh = bw / cr;
        } else {
          bw = bh * cr;
        }
      }
      cw = bw.round();
      ch = bh.round();
      if (cw.isOdd) cw += 1;
      if (ch.isOdd) ch += 1;
      // 壳（= 屏幕框每边外扩 shellPad）在画布居中 → 反推壳图左上角位置
      ccx = ((cw - shellW) / 2).round() - (template.screenX - shellPad) + shellDx;
      ccy = ((ch - shellH) / 2).round() - (template.screenY - shellPad) + shellDy;
    }

    final filter = StringBuffer()
      ..write('[0:v]${contentQuarterTurns == 1 ? 'transpose=1,' : contentQuarterTurns == 3 ? 'transpose=2,' : ''}scale=${template.screenW + 4}:${template.screenH + 4}:'
          'force_original_aspect_ratio=increase,crop=${template.screenW}:'
          '${template.screenH}:((iw-${template.screenW})/2):((ih-${template.screenH})/2),'
          'setsar=1,format=rgba[v0];')
      ..write('[2:v]format=gray[mask];')
      ..write('[v0][mask]alphamerge[va];');

    // ── 背景层：背景图等比 cover 铺画布（可缩放/偏移，壳外永不露白）/ 纯色 ──
    final bgInputs = <String>[];
    if (bgImagePath != null) {
      final (iw, ih) = await imageSize(bgImagePath);
      final cover = math.max(cw / iw, ch / ih);
      final f = cover * bgScale.clamp(1.0, 5.0);
      var fw = (iw * f).round();
      var fh = (ih * f).round();
      if (fw.isOdd) fw += 1;
      if (fh.isOdd) fh += 1;
      var ox = (((cw - fw) / 2) + bgDx).round();
      var oy = (((ch - fh) / 2) + bgDy).round();
      final minOx = cw - fw;
      final minOy = ch - fh;
      if (ox < minOx) ox = minOx;
      if (ox > 0) ox = 0;
      if (oy < minOy) oy = minOy;
      if (oy > 0) oy = 0;
      filter
        ..write('color=c=white:s=${cw}x$ch:'
            'd=$duration[base];')
        ..write('[3:v]scale=$fw:$fh:force_original_aspect_ratio=disable,'
            '${bgBlur && bgBlurSigma > 0 ? 'gblur=sigma=${(bgBlurSigma * cw / 360.0).toStringAsFixed(1)},' : ''}setsar=1,format=rgba[bgv];')
        ..write('[base][bgv]overlay=$ox:$oy:format=auto[bg];');
      bgInputs.add('-i');
      bgInputs.add(_q(bgImagePath));
    } else {
      filter.write('color=c=$bgColor:s=${cw}x$ch:'
          'd=$duration[bg];');
    }

    // ── 内容贴屏幕 → 壳最后画（盖住内容圆弧外扩）──
    filter
      ..write('[bg][va]overlay=${ccx + template.screenX}:${ccy + template.screenY}:'
          'format=auto[bgv];')
      ..write('[bgv][1:v]overlay=$ccx:$ccy:format=auto,format=yuv420p[pre];')
      ..write('[pre]scale=$scaleQuality[vout]');

    final base = [
      '-y',
      '-hwaccel', 'auto',
      '-i', _q(videoPath),
      '-i', _q(template.casePath),
      '-i', _q(maskPath),
      ...bgInputs,
      '-filter_complex', "'$filter'",
      '-map', '[vout]',
      '-map', '0:a?',
      '-r', fps.toStringAsFixed(3),
      '-c:a', 'aac',
      '-b:a', '160k',
      '-movflags', '+faststart',
      // 输出进度到 stdout，SDK 据此触发 Statistics 回调（否则进度恒为 0/100）
      '-progress', 'pipe:1',
    ];

    final ok = await _encodeVideo(
      base: base,
      outputPath: outputPath,
      duration: duration,
      preferHardware: hardware,
      onProgress: onProgress,
      onLog: onLog,
    );
    if (!ok) {
      onLog?.call('[滤镜] $filter');
      throw Exception('视频合成失败');
    }
    // 抽第一帧缩略图（同名 .jpg）：校验文件存在，失败重试一次
    try {
      final thumb = outputPath.replaceAll(RegExp(r'\.mp4$'), '.jpg');
      for (var i = 0; i < 2; i++) {
        await FFmpegKit.execute(
          '-y -i "${outputPath.replaceAll('"', '"')}" -vframes 1 -q:v 3 "${thumb.replaceAll('"', '"')}"',
        );
        if (File(thumb).existsSync()) break;
      }
    } catch (_) {}
  }

  /// 抽取 [atSecond] 时刻合成一张带壳截图
  static Future<String> composeScreenshot({
    required ShellTemplate template,
    required String videoPath,
    required double atSecond,
    required String outputPath,
    String background = 'white',
    bool landscape = false,
    double ratio = 1.0,
    double canvasRatio = 0,
    String? bgImagePath,
    /// 背景高斯模糊开关与强度（sigma 2~40）
    bool bgBlur = false,
    double bgBlurSigma = 18,
    double bgScale = 1.0,
    double bgDx = 0,
    double bgDy = 0,
    int contentQuarterTurns = 0,
}) async {
    final maskPath = await CornerMask.ensure(
        template.screenW, template.screenH, template.cornerR);
    final bgColor = background == 'white' ? 'white' : 'black';

    // 画布：默认 = 壳 + 四周各扩短边1%；屏占比模式 = 屏幕/ratio，壳居中
    // 画布 = 壳框 ÷ 缩放 × 110%；壳框 = 屏幕框每边外扩「屏幕框宽 × 6%」
    // （ratio = 设计壳缩放 25%~100%：100% 时壳占画布 91%，四周留 10% 余量不会出框）
    final shellPad = (template.screenW * 0.06).round();
    final shellW = template.screenW + shellPad * 2;
    final shellH = template.screenH + shellPad * 2;
    var cw, ch, ccx, ccy;
    {
      var bw = shellW / ratio * 1.1;
      var bh = shellH / ratio * 1.1;
      // 画布比例：横屏取倒数（9:16 → 16:9）
      final cr = _canvasRatioFor(template, canvasRatio);
      if (cr > 0) {
        if (bw / bh > cr) {
          bh = bw / cr;
        } else {
          bw = bh * cr;
        }
      }
      cw = bw.round();
      ch = bh.round();
      if (cw.isOdd) cw += 1;
      if (ch.isOdd) ch += 1;
      // 壳（= 屏幕框每边外扩 shellPad）在画布居中 → 反推壳图左上角位置
      ccx = ((cw - shellW) / 2).round() - (template.screenX - shellPad);
      ccy = ((ch - shellH) / 2).round() - (template.screenY - shellPad);
    }

    final filter = StringBuffer()
      ..write('[0:v]${contentQuarterTurns == 1 ? 'transpose=1,' : contentQuarterTurns == 3 ? 'transpose=2,' : ''}scale=${template.screenW + 4}:${template.screenH + 4}:'
          'force_original_aspect_ratio=increase,crop=${template.screenW}:'
          '${template.screenH}:((iw-${template.screenW})/2):((ih-${template.screenH})/2),'
          'setsar=1,format=rgba[v0];')
      ..write('[2:v]format=gray[mask];')
      ..write('[v0][mask]alphamerge[va];');

    final bgInputs = <String>[];
    if (bgImagePath != null) {
      final (iw, ih) = await imageSize(bgImagePath);
      final cover = math.max(cw / iw, ch / ih);
      final f = cover * bgScale.clamp(1.0, 5.0);
      var fw = (iw * f).round();
      var fh = (ih * f).round();
      if (fw.isOdd) fw += 1;
      if (fh.isOdd) fh += 1;
      var ox = (((cw - fw) / 2) + bgDx).round();
      var oy = (((ch - fh) / 2) + bgDy).round();
      final minOx = cw - fw;
      final minOy = ch - fh;
      if (ox < minOx) ox = minOx;
      if (ox > 0) ox = 0;
      if (oy < minOy) oy = minOy;
      if (oy > 0) oy = 0;
      filter
        ..write('color=c=white:s=${cw}x$ch:d=1[base];')
        ..write('[3:v]scale=$fw:$fh:force_original_aspect_ratio=disable,'
            '${bgBlur && bgBlurSigma > 0 ? 'gblur=sigma=${(bgBlurSigma * cw / 360.0).toStringAsFixed(1)},' : ''}setsar=1,format=rgba[bgv];')
        ..write('[base][bgv]overlay=$ox:$oy:format=auto[bg];');
      bgInputs.addAll(['-i', _q(bgImagePath)]);
    } else {
      filter.write('color=c=$bgColor:s=${cw}x$ch:d=1[bg];');
    }

    filter
      ..write('[bg][va]overlay=${ccx + template.screenX}:${ccy + template.screenY}:'
          'format=auto[bgv];')
      ..write('[bgv][1:v]overlay=$ccx:$ccy:format=auto,format=rgba[vout]');

    final cmd = [
      '-y',
      '-ss', atSecond.toStringAsFixed(3),
      '-i', _q(videoPath),
      '-i', _q(template.casePath),
      '-i', _q(maskPath),
      ...bgInputs,
      '-filter_complex', "'$filter'",
      '-map', '[vout]',
      '-frames:v', '1',
      _q(outputPath),
    ].join(' ');

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('截图合成失败: ${session.getOutput()}');
    }
    return outputPath;
  }

  /// 单帧图片合成带壳图（图片创作）：输入一张图片 → 输出带壳 PNG
  static Future<String> composeImage({
    required ShellTemplate template,
    required String imagePath,
    required String outputPath,
    String background = 'white',
    bool landscape = false,
    double ratio = 1.0,
    double canvasRatio = 0,
    String? bgImagePath,
    /// 背景高斯模糊开关与强度（sigma 2~40）
    bool bgBlur = false,
    double bgBlurSigma = 18,
    double bgScale = 1.0,
    double bgDx = 0,
    double bgDy = 0,
    double shellDx = 0,
  double shellDy = 0,
  /// 内容旋转 90° 次数：1=顺时针，3=逆时针（0=不转）
  int contentQuarterTurns = 0,
}) async {
    // 与视频合成一致：R 角裁切 + 四边裁 2px + 画布外扩 2% 白底
    final maskPath = await CornerMask.ensure(
        template.screenW, template.screenH, template.cornerR);
    final bgColor = background == 'white' ? 'white' : 'black';

    // 画布 = 壳框 ÷ 缩放 × 110%；壳框 = 屏幕框每边外扩「屏幕框宽 × 6%」
    // （ratio = 设计壳缩放 25%~100%：100% 时壳占画布 91%，四周留 10% 余量不会出框）
    final shellPad = (template.screenW * 0.06).round();
    final shellW = template.screenW + shellPad * 2;
    final shellH = template.screenH + shellPad * 2;
    var cw, ch, ccx, ccy;
    {
      var bw = shellW / ratio * 1.1;
      var bh = shellH / ratio * 1.1;
      // 画布比例：横屏取倒数（9:16 → 16:9）
      final cr = _canvasRatioFor(template, canvasRatio);
      if (cr > 0) {
        if (bw / bh > cr) {
          bh = bw / cr;
        } else {
          bw = bh * cr;
        }
      }
      cw = bw.round();
      ch = bh.round();
      if (cw.isOdd) cw += 1;
      if (ch.isOdd) ch += 1;
      // 壳（= 屏幕框每边外扩 shellPad）在画布居中 → 反推壳图左上角位置
      ccx = ((cw - shellW) / 2).round() - (template.screenX - shellPad) + shellDx;
      ccy = ((ch - shellH) / 2).round() - (template.screenY - shellPad) + shellDy;
    }

    final filter = StringBuffer()
      ..write('[0:v]${contentQuarterTurns == 1 ? 'transpose=1,' : contentQuarterTurns == 3 ? 'transpose=2,' : ''}scale=${template.screenW + 4}:${template.screenH + 4}:'
          'force_original_aspect_ratio=increase,crop=${template.screenW}:'
          '${template.screenH}:((iw-${template.screenW})/2):((ih-${template.screenH})/2),'
          'setsar=1,format=rgba[v0];')
      ..write('[2:v]format=gray[mask];')
      ..write('[v0][mask]alphamerge[va];');

    final bgInputs = <String>[];
    if (bgImagePath != null) {
      final (iw, ih) = await imageSize(bgImagePath);
      final cover = math.max(cw / iw, ch / ih);
      final f = cover * bgScale.clamp(1.0, 5.0);
      var fw = (iw * f).round();
      var fh = (ih * f).round();
      if (fw.isOdd) fw += 1;
      if (fh.isOdd) fh += 1;
      var ox = (((cw - fw) / 2) + bgDx).round();
      var oy = (((ch - fh) / 2) + bgDy).round();
      final minOx = cw - fw;
      final minOy = ch - fh;
      if (ox < minOx) ox = minOx;
      if (ox > 0) ox = 0;
      if (oy < minOy) oy = minOy;
      if (oy > 0) oy = 0;
      filter
        ..write('color=c=white:s=${cw}x$ch:d=1[base];')
        ..write('[3:v]scale=$fw:$fh:force_original_aspect_ratio=disable,'
            '${bgBlur && bgBlurSigma > 0 ? 'gblur=sigma=${(bgBlurSigma * cw / 360.0).toStringAsFixed(1)},' : ''}setsar=1,format=rgba[bgv];')
        ..write('[base][bgv]overlay=$ox:$oy:format=auto[bg];');
      bgInputs.addAll(['-i', _q(bgImagePath)]);
    } else {
      filter.write('color=c=$bgColor:s=${cw}x$ch:d=1[bg];');
    }

    filter
      ..write('[bg][va]overlay=${ccx + template.screenX}:${ccy + template.screenY}:'
          'format=auto[bgv];')
      ..write('[bgv][1:v]overlay=$ccx:$ccy:format=auto,format=rgba[vout]');

    final cmd = [
      '-y',
      '-i', _q(imagePath),
      '-i', _q(template.casePath),
      '-i', _q(maskPath),
      ...bgInputs,
      '-filter_complex', "'$filter'",
      '-map', '[vout]',
      '-frames:v', '1',
      _q(outputPath),
    ].join(' ');

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('图片合成失败: ${session.getOutput()}');
    }
    return outputPath;
  }

  /// 画布宽高比在横屏要取倒数：横屏模板是竖屏模板逆时针转 90° 得到的，
  /// 竖屏选 9:16 时横屏就应该是 16:9。比例不翻转的话横屏画布会按竖屏比例算
  /// （宽高互换），壳在画布内只占很小一块，和预览对不上。
  static double _canvasRatioFor(ShellTemplate t, double r) {
    if (r <= 0) return 0;
    return t.caseWidth > t.caseHeight ? 1 / r : r;
  }

  /// 视频编码器自动降级：硬件 mediacodec → libx264 → mpeg4。
  ///
  /// 背景：部分修补版 ffmpeg 没编译 libx264（日志里会报 `Unknown encoder 'libx264'`），
  /// 而 mediacodec 是启用的；mpeg4 是 ffmpeg 内置编码器，几乎永远在，作为最后兜底。
  /// `Unknown encoder` 属于立即失败，逐个换掉几乎不耗时。
  static Future<bool> _encodeVideo({
    required List<String> base,
    required String outputPath,
    required double duration,
    required bool preferHardware,
    void Function(double progress, String speed)? onProgress,
    void Function(String log)? onLog,
  }) async {
    final attempts = <List<String>>[
      if (preferHardware) ['-c:v', 'h264_mediacodec', '-b:v', '10M', '-bufsize', '20M'],
      ['-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23'],
      ['-c:v', 'mpeg4', '-q:v', '3'],
    ];
    for (var i = 0; i < attempts.length; i++) {
      final ok = await _run(
        [...base, ...attempts[i], _q(outputPath)],
        duration,
        onProgress,
        onLog,
      );
      if (ok) return true;
      if (i < attempts.length - 1) {
        onLog?.call('[提示] 编码器 ${attempts[i][1]} 不可用，自动换下一个');
      }
    }
    return false;
  }

  /// 抽一帧作为实时预览的内容（不做整幅合成，快）
  static Future<String?> extractFrame({
    required String videoPath,
    required String outputPath,
    double atSecond = 0,
  }) async {
    final cmd = '-y -ss ${atSecond.toStringAsFixed(3)} '
        '-i ${_q(videoPath)} -vframes 1 -q:v 3 ${_q(outputPath)}';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) return null;
    return outputPath;
  }

  /// 批量抽帧做胶片条缩略图（90x160 cover 裁切）
  static Future<List<String>> extractThumbnails({
    required String videoPath,
    required String outDir,
    int count = 10,
    double durationSec = 0,
  }) async {
    final list = <String>[];
    for (var i = 0; i < count; i++) {
      final t = durationSec <= 0 ? 0.0 : (durationSec * i / count);
      final out = '$outDir/thumb_$i.jpg';
      final cmd = '-y -ss ${t.toStringAsFixed(3)} -i ${_q(videoPath)} '
          '-vframes 1 -q:v 5 -vf '
          '"scale=90:160:force_original_aspect_ratio=increase,crop=90:160" '
          '${_q(out)}';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) list.add(out);
    }
    return list;
  }

  static String _q(String p) => '"${p.replaceAll('"', '\\"')}"';

  /// 透明图合成：背景（纯色或图片）→ 透明外壳 → 内容（视频/图片）贴合屏幕透明区
  /// [bgColor] 背景色 0xRRGGBB（未选背景图时生效）
  /// [bgImagePath] 背景图（置于最底层；等比缩放不变形 + 用户偏移/缩放）
  /// [bgScale] 背景图缩放系数，1.0 = 等比铺满画布(cover)
  /// [bgDx]/[bgDy] 背景图相对居中的像素偏移
  /// [ratio] 屏占比：屏幕框占成品画布比例（如 0.9 = 标定框占 90%，四周等宽留白）
  /// [canvasRatio] 画布宽高比（9/16、16/9、3/4、4/3、1/1.414、1.414/1；0=按屏占比自然比例）
  static Future<void> composeTransparent({
    required ShellTemplate template,
    /// 内容可选：为空时只做「背景 + 外壳」的静态图
    String? contentPath,
    required String outputPath,
    required bool isVideo,
    required int bgColor,
    String? bgImagePath,
    /// 背景高斯模糊开关与强度（sigma 2~40）
    bool bgBlur = false,
    double bgBlurSigma = 18,
    double bgScale = 1.0,
    double bgDx = 0,
    double bgDy = 0,
    required double ratio,
    double canvasRatio = 0,
    VideoInfo? info,
    Quality quality = Quality.original,
    /// 是否优先用硬件编码（我的页设置）
    bool hardware = true,
    /// 导出帧率；0 = 用视频探测帧率
    int fpsOverride = 0,
    void Function(double progress, String speed)? onProgress,
    void Function(String log)? onLog,
    double shellDx = 0,
  double shellDy = 0,
  /// 内容旋转 90° 次数：1=顺时针，3=逆时针（0=不转）
  int contentQuarterTurns = 0,
}) async {
    final sw = template.screenW;
    final sh = template.screenH;
    // 内容可以为空：只做「背景 + 外壳」的静态图（屏幕区域保持透明，露出背景）
    final hasContent = contentPath != null && contentPath.isNotEmpty;
    // 没有内容就没有视频可编，按单帧输出
    final asVideo = isVideo && hasContent;
    // 遮罩圆弧统一外扩 5px（防白边）；溢出由外壳盖住（外壳最后画）
    final maskPath = await CornerMask.ensure(sw, sh, template.cornerR);

    // 画布 = 屏幕区 / 屏占比，四周等宽留白（偶数化）；可选画布宽高比调整
    // 画布 = 壳框 ÷ 缩放 × 110%；壳框 = 屏幕框每边外扩「屏幕框宽 × 6%」
    final shellPad = (sw * 0.06).round();
    final shellW = sw + shellPad * 2;
    final shellH = sh + shellPad * 2;
    var bw = shellW / ratio * 1.1;
    var bh = shellH / ratio * 1.1;
    final cr = _canvasRatioFor(template, canvasRatio);
    if (cr > 0) {
      if (bw / bh > cr) {
        bh = bw / cr;
      } else {
        bw = bh * cr;
      }
    }
    var cw = bw.round();
    var ch = bh.round();
    if (cw.isOdd) cw += 1;
    if (ch.isOdd) ch += 1;
    final scx = ((cw - shellW) / 2).round() + shellPad + shellDx;
    final scy = ((ch - shellH) / 2).round() + shellPad + shellDy;
    final ccx = scx - template.screenX;
    final ccy = scy - template.screenY;

    // 时长兜底：?? 只挡 null、挡不住 0（部分录屏文件读不到时长），
    // 时长 0 会让背景源变成 d=0 → ffmpeg 直接失败。
    // 这里和普通合成台 composeVideo 用同一个判据（<=0 就当未知，兜到 60 秒）
    final dur0 = info?.durationSeconds ?? 0;
    final durKnown = dur0.isFinite && dur0 > 0;
    final duration = asVideo ? (durKnown ? dur0 : 60.0) : 1.0;
    final fps0 = info?.fps ?? 0;
    final fps = fpsOverride > 0
        ? fpsOverride.toDouble()
        : (asVideo && fps0.isFinite && fps0 > 0 && fps0 <= 240 ? fps0 : 30.0);

    final scaleQuality = switch (quality) {
      Quality.original => 'trunc(iw/2)*2:trunc(ih/2)*2',
      Quality.p1080 => '-2:1920',
      Quality.p720 => '-2:1280',
    };

    // 输入下标随“有没有内容”变化：有内容时 [0]=内容 [1]=外壳 [2]=遮罩
    final caseIdx = hasContent ? 1 : 0;
    final maskIdx = hasContent ? 2 : 1;
    final bgIdx = caseIdx + 2; // 有背景图时的输入下标

    final filter = StringBuffer();
    if (hasContent) {
      filter
        ..write('[0:v]${contentQuarterTurns == 1 ? 'transpose=1,' : contentQuarterTurns == 3 ? 'transpose=2,' : ''}scale=${sw + 4}:${sh + 4}:'
            'force_original_aspect_ratio=increase,crop=$sw:'
            '$sh:((iw-$sw)/2):((ih-$sh)/2),'
            'setsar=1,format=rgba[v0];')
        ..write('[$maskIdx:v]format=gray[mask];')
        ..write('[v0][mask]alphamerge[va];');
    }

    // ── 背景层（最底层）──
    final bgPath = bgImagePath;
    if (bgPath != null) {
      // 背景图等比 cover，再乘用户缩放（0.5×~2×，默认 1×）：
      // 图 ≥ 画布 → 受覆盖约束（永不露底）；图 < 画布 → 居中（四周露出底色）
      final (iw, ih) = await imageSize(bgPath);
      final cover = math.max(cw / iw, ch / ih);
      final f = cover * bgScale.clamp(0.5, 2.0);
      var fw = (iw * f).round();
      var fh = (ih * f).round();
      if (fw.isOdd) fw += 1;
      if (fh.isOdd) fh += 1;
      var ox = (((cw - fw) / 2) + bgDx).round();
      var oy = (((ch - fh) / 2) + bgDy).round();
      if (fw >= cw) {
        final minOx = cw - fw; // 背景图右缘 ≥ 画布右缘
        if (ox < minOx) ox = minOx;
        if (ox > 0) ox = 0;
      } else {
        ox = ((cw - fw) / 2).round();
      }
      if (fh >= ch) {
        final minOy = ch - fh;
        if (oy < minOy) oy = minOy;
        if (oy > 0) oy = 0;
      } else {
        oy = ((ch - fh) / 2).round();
      }
      // 背景图盖在白色底上（图外露出白底兜底）
      filter
        ..write('color=c=white:s=${cw}x$ch:d=$duration[base];')
        ..write('[$bgIdx:v]scale=$fw:$fh:force_original_aspect_ratio=disable,'
            '${bgBlur && bgBlurSigma > 0 ? 'gblur=sigma=${(bgBlurSigma * cw / 360.0).toStringAsFixed(1)},' : ''}setsar=1,format=rgba[bgv];')
        ..write('[base][bgv]overlay=$ox:$oy:format=auto[bg0];');
    } else {
      final hex = (bgColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
      filter.write('color=c=0x$hex:s=${cw}x$ch:d=$duration[bg0];');
    }

    // ── 图层：背景（最底层）→ 内容（可选，R 角遮罩贴屏幕）→ 外壳（最后画，盖住内容圆弧外扩）──
    // 没有内容时跳过内容层：屏幕区域保持透明，直接露出背景
    var contentLayer = 'bg0';
    if (hasContent) {
      filter.write('[bg0][va]overlay=$scx:$scy:format=auto[bg1];');
      contentLayer = 'bg1';
    }
    filter
      ..write('[$contentLayer][$caseIdx:v]overlay=$ccx:$ccy:format=auto,'
          'format=${asVideo ? 'yuv420p' : 'rgba'}[pre];')
      ..write('[pre]scale=$scaleQuality[vout]');

    final bgInput = bgPath == null
        ? const <String>[]
        : <String>['-i', _q(bgPath)];
    final inputs = [
      '-y',
      if (hasContent) ...['-i', _q(contentPath)],
      '-i', _q(template.casePath),
      '-i', _q(maskPath),
      ...bgInput,
    ];

    if (asVideo) {
      final base = [
        ...inputs,
        '-filter_complex', "'$filter'",
        '-map', '[vout]',
        '-map', '0:a?',
        '-r', fps.toStringAsFixed(3),
        '-c:a', 'aac',
        '-b:a', '160k',
        '-movflags', '+faststart',
        '-progress', 'pipe:1',
        // 时长没读到时背景源兜到 60 秒，用 -shortest 收在内容结束处，避免 60 秒定格画面
        if (!durKnown) '-shortest',
      ];
      final ok = await _encodeVideo(
        base: base,
        outputPath: outputPath,
        duration: duration,
        preferHardware: hardware,
        onProgress: onProgress,
        onLog: onLog,
      );
      if (!ok) {
        onLog?.call('[滤镜] $filter');
        throw Exception('视频合成失败');
      }
      // 抽第一帧缩略图
      try {
        final thumb = outputPath.replaceAll(RegExp(r'\.mp4$'), '.jpg');
        for (var i = 0; i < 2; i++) {
          await FFmpegKit.execute(
            '-y -i "${outputPath.replaceAll('"', '"')}" -vframes 1 -q:v 3 "${thumb.replaceAll('"', '"')}"',
          );
          if (File(thumb).existsSync()) break;
        }
      } catch (_) {}
      return;
    }

    final cmd = [
      ...inputs,
      '-filter_complex', "'$filter'",
      '-map', '[vout]',
      '-frames:v', '1',
      _q(outputPath),
    ].join(' ');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('图片合成失败: ${session.getOutput()}');
    }
  }

  static final _timeRe = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)');

  static Future<bool> _run(
    List<String> cmdParts,
    double duration,
    void Function(double progress, String speed)? onProgress,
    void Function(String log)? onLog,
  ) async {
    final done = Completer<bool>();
    final started = DateTime.now();

    await FFmpegKit.executeAsync(
      cmdParts.join(' '),
      (session) async {
        final rc = await session.getReturnCode();
        done.complete(ReturnCode.isSuccess(rc));
        if (!ReturnCode.isSuccess(rc)) {
          final out = await session.getOutput() ?? '';
          // ffmpeg 输出前面全是输入/流信息，真正的错误夹杂在后面几行 →
          // 只挑“像错误”的行，挑不到就退回末尾 8 行（否则弹窗第一条永远是信息行）
          final lines = out
              .split('\n')
              .map((l) => l.trimRight())
              .where((l) => l.trim().isNotEmpty)
              .toList();
          const keys = [
            'Error', 'error', 'Invalid', 'invalid', 'failed', 'Failed',
            'Unable', 'unable', 'No such', 'not found', 'Conversion',
            'deprecated', 'Unknown', 'unknown', 'not supported', 'Cannot',
          ];
          var picked =
              lines.where((l) => keys.any((k) => l.contains(k))).toList();
          if (picked.length > 12) {
            picked = picked.sublist(picked.length - 12);
          }
          if (picked.isEmpty) {
            picked = lines.length > 8
                ? lines.sublist(lines.length - 8)
                : lines;
          }
          onLog?.call('[错误] ${picked.join('\n')}');
        }
      },
      (log) {
        final msg = log.getMessage().trim();
        if (msg.isEmpty) return;
        onLog?.call(msg);
        // 从 stderr 的 time=00:00:12.34 解析进度（硬编软编都输出，最可靠）
        if (onProgress != null && duration > 0) {
          final m = _timeRe.firstMatch(msg);
          if (m != null) {
            final h = int.parse(m.group(1)!);
            final min = int.parse(m.group(2)!);
            final sec = double.parse(m.group(3)!);
            final t = h * 3600 + min * 60 + sec;
            final p = (t / duration).clamp(0.0, 1.0).toDouble();
            final elapsed = DateTime.now().difference(started).inSeconds;
            var speed = '';
            if (elapsed > 0 && p > 0.01) {
              final remain = (elapsed / p) - elapsed;
              speed = '已用 ${_fmtDur(elapsed)} · 预计剩余 ${_fmtDur(remain.toInt())}';
            }
            onProgress(p, speed);
          }
        }
      },
      (stats) {
        // Statistics 回调保留作为兜底（软编路径）
        if (onProgress == null) return;
        final timeUs = stats.getTime();
        if (duration > 0 && timeUs > 0) {
          final p = (timeUs / (duration * 1e6)).clamp(0.0, 1.0).toDouble();
          onProgress(p, '');
        }
      },
    );

    return done.future;
  }

  static String _fmtDur(int sec) {
    if (sec < 60) return '$sec秒';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m分$s秒';
  }

  /// 动图（GIF / 动态 WebP）转成 MP4，供裁切与合成使用
  static Future<String> gifToMp4({
    required String inputPath,
    required String outputPath,
  }) async {
    final cmd = '-y -i "$inputPath" -movflags +faststart '
        '-pix_fmt yuv420p -c:v libx264 -crf 20 -an "$outputPath"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) throw Exception('动图转换失败');
    return outputPath;
  }
}
