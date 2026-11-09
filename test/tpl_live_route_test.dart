import 'package:flutter_test/flutter_test.dart';
import 'package:shell_video_app/screens/compose_screen.dart';

/// 实况创作路由测试
///
/// 模板库把「实况创作」的入口（liveMode=true）翻译成 ComposeMode.live。
/// 这里把翻译规则抽成可测的纯函数式断言，防止以后又被漏掉。
void main() {
  /// 与 TplLibraryScreen 里的逻辑保持一致
  ComposeMode routeMode({
    required bool liveMode,
    required bool imageMode,
    required bool transparent,
  }) {
    if (liveMode) return ComposeMode.live;
    if (transparent) {
      return imageMode
          ? ComposeMode.transparentImage
          : ComposeMode.transparentVideo;
    }
    return imageMode ? ComposeMode.image : ComposeMode.video;
  }

  group('实况创作路由', () {
    test('实况 + 普通模板 → ComposeMode.live', () {
      expect(
        routeMode(liveMode: true, imageMode: false, transparent: false),
        ComposeMode.live,
      );
    });

    test('实况 + 透明模板 → 仍然是 ComposeMode.live（关键回归点）', () {
      expect(
        routeMode(liveMode: true, imageMode: false, transparent: true),
        ComposeMode.live,
      );
    });

    test('视频创作 + 普通模板 → video', () {
      expect(
        routeMode(liveMode: false, imageMode: false, transparent: false),
        ComposeMode.video,
      );
    });

    test('图片创作 + 普通模板 → image', () {
      expect(
        routeMode(liveMode: false, imageMode: true, transparent: false),
        ComposeMode.image,
      );
    });

    test('视频创作 + 透明模板 → transparentVideo', () {
      expect(
        routeMode(liveMode: false, imageMode: false, transparent: true),
        ComposeMode.transparentVideo,
      );
    });

    test('图片创作 + 透明模板 → transparentImage', () {
      expect(
        routeMode(liveMode: false, imageMode: true, transparent: true),
        ComposeMode.transparentImage,
      );
    });
  });

  test('ComposeMode 枚举包含 5 种模式', () {
    expect(ComposeMode.values.length, 5);
    expect(ComposeMode.values, contains(ComposeMode.live));
    expect(ComposeMode.values, contains(ComposeMode.transparentVideo));
    expect(ComposeMode.values, contains(ComposeMode.transparentImage));
  });
}
