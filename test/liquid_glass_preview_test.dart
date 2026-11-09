// 液态玻璃底栏「改前 / 改后」对照预览图
//
// 运行：flutter test test/liquid_glass_preview_test.dart
// 输出：build/liquid_glass_preview_colorful.png（花哨背景）
//       build/liquid_glass_preview_light.png   （App 真实浅灰背景）
// 只是用来看效果的，不需要可以删掉这个文件
//
// 注意：widget test 里截图必须包在 tester.runAsync 里，否则软件光栅化永远等不到结果
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_video_app/widgets/liquid_glass.dart';

const double _itemW = 129.3; // (402 - 14) / 3，与底栏 Tab 等分一致
const _barTint = [Color(0x6BFFFFFF), Color(0x38FFFFFF)];
const _pillTint = [Color(0xCCFFFFFF), Color(0xA8FFFFFF)];

/// 加载成功的中文字体族名（加载失败就退回默认字体）
String? _cjkFamily;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter test 默认不带字体：不加载的话 Icon 和中文都会渲染成方框
    final iconFont = _materialIconsFont();
    if (iconFont != null) await _loadFont('MaterialIcons', iconFont);
    for (final path in const [
      r'C:\Windows\Fonts\simhei.ttf',
      r'C:\Windows\Fonts\Deng.ttf',
      r'C:\Windows\Fonts\msyh.ttc',
    ]) {
      final f = File(path);
      if (f.existsSync()) {
        await _loadFont('CJK', f);
        _cjkFamily = 'CJK';
        break;
      }
    }
  });

  testWidgets('花哨背景', (tester) => _render(tester, 'colorful', const _ColorBackdrop()));
  testWidgets('浅灰背景', (tester) => _render(tester, 'light', const ColoredBox(color: Color(0xFFF4F5F7))));
}

/// 找 Flutter SDK 里的 MaterialIcons 字体。
/// 注意：测试进程跑在 flutter_tester.exe 里，不能按 dart 可执行文件推路径，
/// 所以优先用 FLUTTER_ROOT，再逐级向上找 bin/cache/artifacts/material_fonts。
File? _materialIconsFont() {
  const rel = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final f = File('$root/$rel');
    if (f.existsSync()) return f;
  }
  var d = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final f = File('${d.path}/$rel');
    if (f.existsSync()) return f;
    final up = d.parent;
    if (up.path == d.path) break;
    d = up;
  }
  return null;
}

Future<void> _loadFont(String family, File f) async {
  if (!f.existsSync()) return;
  final loader = FontLoader(family);
  loader.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

Future<void> _render(WidgetTester tester, String name, Widget backdrop) async {
  tester.view.physicalSize = const Size(1000, 820);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Stack(
            children: [
              Positioned.fill(child: backdrop),
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Row(label: 'BEFORE  frosted', child: _OldBar()),
                      _Row(label: 'AFTER  liquid glass', child: _NewBar()),
                      _Row(
                        label: 'AFTER  compose action bar',
                        child: _ComposeBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // 截图必须在 runAsync 里做真实异步光栅化
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/liquid_glass_preview_$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: _cjkFamily,
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 花哨背景：模糊 / 提饱和效果在这种背景上差别最明显
class _ColorBackdrop extends StatelessWidget {
  const _ColorBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B5CFF),
            Color(0xFF3AA0FF),
            Color(0xFF35D6A4),
            Color(0xFFFFB347),
            Color(0xFFFF5C8A),
          ],
        ),
      ),
      child: Stack(
        children: [
          for (var i = 0; i < 14; i++)
            Positioned(
              left: (i * 83) % 340 + 6,
              top: (i * 47) % 220 + 8,
              child: Container(
                width: 40.0 + (i % 4) * 20,
                height: 40.0 + (i % 3) * 24,
                decoration: BoxDecoration(
                  color: const [
                    Color(0xFFFFE066),
                    Color(0xFFFF6B6B),
                    Color(0xFF4ECDC4),
                    Color(0xFF1A535C),
                    Color(0xFFFFFFFF),
                  ][i % 5]
                      .withValues(alpha: .55),
                  shape: i.isEven ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: i.isEven ? null : BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final bool active;
  const _TabSpec(this.label, this.icon, this.active);
}

const _tabs = [
  _TabSpec('创作', Icons.add_box, true),
  _TabSpec('图库', Icons.video_library_outlined, false),
  _TabSpec('我的', Icons.person_outline, false),
];

/// 改前：原实现（BackdropFilter 22 + 白色 30% + 白边）
class _OldBar extends StatelessWidget {
  const _OldBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .30),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .72),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 7,
            top: 7,
            width: _itemW,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xEBFFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
          const Positioned.fill(child: _TabRow()),
        ],
      ),
    );
  }
}

/// 改后：液态玻璃
class _NewBar extends StatelessWidget {
  const _NewBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          const Positioned.fill(
            child: LiquidGlass(
              borderRadius: 26,
              blur: 24,
              tint: _barTint,
            ),
          ),
          const Positioned(
            left: 7,
            top: 7,
            width: _itemW,
            height: 50,
            child: LiquidGlass(
              borderRadius: 17,
              blur: 10,
              tint: _pillTint,
              glow: Color(0xFF0A84FF),
            ),
          ),
          const Positioned.fill(child: _TabRow()),
        ],
      ),
    );
  }
}

/// compose 底部操作栏（带 child 的液态玻璃，验证按钮在玻璃里的样子）
class _ComposeBar extends StatelessWidget {
  const _ComposeBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: LiquidGlass(
        borderRadius: 22,
        blur: 20,
        tint: const [Color(0xB3FFFFFF), Color(0x8FFFFFFF)],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(
                child: _Btn(
                  icon: Icons.photo_camera_outlined,
                  label: '截图',
                  primary: false,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _Btn(
                  icon: Icons.movie_outlined,
                  label: '导出带壳视频',
                  primary: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与 compose_screen 里 _ActionBtn 一致的样式
class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.primary});

  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: primary
            ? const Color(0xFF0A84FF)
            : const Color(0xFF0A84FF).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: primary ? Colors.white : const Color(0xFF0A84FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: _cjkFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : const Color(0xFF0A84FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          for (final t in _tabs)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    t.icon,
                    size: 23,
                    color: t.active
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF8E8E93),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontFamily: _cjkFamily,
                      fontSize: 10.5,
                      fontWeight: t.active ? FontWeight.w700 : FontWeight.w500,
                      color: t.active
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
