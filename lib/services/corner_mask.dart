import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 生成屏幕区域的圆角遮罩（白色=屏幕内，黑色=圆角外）
class CornerMask {
  /// 生成并缓存圆角遮罩 PNG，返回路径
  /// 圆弧统一向外扩 5px（直边不动）：R 值算偏小时少裁一点，防白边；
  /// 溢出由外壳盖住（普通台外壳最后画，透明台也改为外壳最后画）
  static Future<String> ensure(int w, int h, int r) async {
    final cache = await getTemporaryDirectory();
    final dir = Directory(p.join(cache.path, 'masks'));
    await dir.create(recursive: true);
    final o = 5;
    final path = p.join(dir.path, 'mask_${w}x${h}_r${r}_o$o.png');
    if (await File(path).exists()) return path;

    final image = img.Image(width: w, height: h);
    image.clear(img.ColorRgb8(0, 0, 0));
    final white = img.ColorRgb8(255, 255, 255);

    // 直边保持原位置（贴合屏幕边缘）
    img.fillRect(image, x1: r, y1: 0, x2: w - r - 1, y2: h - 1, color: white);
    img.fillRect(image, x1: 0, y1: r, x2: w - 1, y2: h - r - 1, color: white);
    // 四角圆：圆心向外扩 o，半径不变
    img.fillCircle(image, x: r - o, y: r - o, radius: r, color: white);
    img.fillCircle(image, x: w - r - 1 + o, y: r - o, radius: r, color: white);
    img.fillCircle(image, x: r - o, y: h - r - 1 + o, radius: r, color: white);
    img.fillCircle(image, x: w - r - 1 + o, y: h - r - 1 + o, radius: r, color: white);

    final png = img.encodePng(image);
    await File(path).writeAsBytes(png);
    return path;
  }
}
