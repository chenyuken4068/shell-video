import 'dart:io';

/// 读取图片宽高（PNG / JPEG，无需完整解码）
Future<(int, int)> imageSize(String path) async {
  final bytes = await File(path).readAsBytes();
  // PNG IHDR
  if (bytes.length > 24 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    return (w, h);
  }
  // JPEG SOF 扫描
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i < bytes.length - 8) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker >= 0xC0 && marker <= 0xCF &&
          marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
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
