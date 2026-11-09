import 'package:ffmpeg_kit_flutter_video/ffprobe_kit.dart';

/// 视频媒体信息
class VideoInfo {
  final int width;
  final int height;
  final double durationSeconds;
  final double fps;
  final int rotation;
  final bool hasAudio;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.fps,
    required this.rotation,
    required this.hasAudio,
  });

  String get resolutionLabel {
    final longEdge = width >= height ? width : height;
    if (longEdge >= 3800) return '4K';
    if (longEdge >= 1800) return '1080P';
    if (longEdge >= 1200) return '720P';
    return '标清';
  }

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(0).padLeft(2, '0')}';
  }
}

/// 用 ffprobe 读取视频信息（自动识别分辨率/时长/帧率）
class VideoInfoReader {
  static Future<VideoInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      throw Exception('无法读取视频信息: ${session.getOutput()}');
    }

    int width = 0, height = 0, rotation = 0;
    double duration = 0, fps = 30, streamDuration = 0;
    var hasAudio = false;

    for (final s in info.getStreams()) {
      final type = s.getType() ?? '';
      if (type == 'video') {
        width = s.getWidth() ?? width;
        height = s.getHeight() ?? height;
        // 帧率：avg_frame_rate 或 r_frame_rate（形如 "30000/1001"）
        final fpsStr = s.getAverageFrameRate() ?? s.getRealFrameRate();
        if (fpsStr != null && fpsStr.isNotEmpty) {
          final f = _parseFraction(fpsStr);
          if (f != null && f > 0) fps = f;
        }
        // 旋转信息在 tags 中（rotate=90 表示竖拍视频）
        final tags = s.getTags();
        if (tags != null) {
          final rot = int.tryParse('${tags['rotate']}');
          if (rot != null) rotation = rot;
        }
        // 有些文件的 format 段没有时长（录屏/分段 mp4 常见），用视频流自身的 duration 兜底
        final sd = double.tryParse(s.getStringProperty('duration') ?? '');
        if (sd != null && sd.isFinite && sd > 0) streamDuration = sd;
      } else if (type == 'audio') {
        hasAudio = true;
      }
    }

    if (width == 0 || height == 0) {
      throw Exception('未找到视频流');
    }

    // 旋转 90/270 时宽高互换（竖屏手机视频常见）
    if (rotation == 90 || rotation == 270) {
      final t = width;
      width = height;
      height = t;
    }

    if (duration <= 0 && streamDuration > 0) duration = streamDuration;
    final infoDuration = double.tryParse(info.getDuration() ?? '');
    if (duration <= 0 && infoDuration != null && infoDuration.isFinite) {
      duration = infoDuration;
    }

    return VideoInfo(
      width: width,
      height: height,
      durationSeconds: duration,
      fps: fps,
      rotation: rotation,
      hasAudio: hasAudio,
    );
  }

  static double? _parseFraction(String s) {
    final parts = s.split('/');
    if (parts.length == 2) {
      final n = double.tryParse(parts[0]);
      final d = double.tryParse(parts[1]);
      if (n != null && d != null && d != 0) return n / d;
    }
    return double.tryParse(s);
  }
}
