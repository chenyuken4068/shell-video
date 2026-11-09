// 验证新方案：内容层画在卡框坐标系 + ScreenHoleClipper 旋转洞裁剪
// 期望：横屏(p=1)时可见块 = 292.5 x 131.3（横条），且【左红右蓝】= 内容正立
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_video_app/widgets/screen_hole_clipper.dart';

void main() {
  testWidgets('横屏内容层方向（新方案）', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // xiaomi14 横屏 p=1 的实际几何
    const caseW = 1397.0, caseH = 2984.0;
    const scrX = 95.0, scrY = 157.0, scrW = 1198.0, scrH = 2669.0, cornerR = 132.0;
    const cw0 = 1426.0, ch0 = 3012.0;
    const landW = 330.0, landH = landW / (ch0 / cw0);
    const rCase = caseW / caseH;
    const fitH = landH < landW / rCase ? landH : landW / rCase;
    const fitW = fitH * rCase;
    const sInner = fitW / caseW;
    final k = (caseW * (landW / ch0)) / fitW;
    final angle = -math.pi / 2;

    final holeW = scrW * sInner, holeH = scrH * sInner;
    final ct = math.cos(angle), st = math.sin(angle);
    final offX = ((scrX + scrW / 2) - caseW / 2) * sInner * k;
    final offY = ((scrY + scrH / 2) - caseH / 2) * sInner * k;
    final holeCx = landW / 2 + offX * ct - offY * st;
    final holeCy = landH / 2 + offX * st + offY * ct;
    final holeBw = (holeW * ct.abs() + holeH * st.abs()) * k;
    final holeBh = (holeW * st.abs() + holeH * ct.abs()) * k;

    // 便于对照：把算出来的量写进文件名旁边
    // ignore: avoid_print
    print('期望可见块: ${holeBw.toStringAsFixed(1)} x ${holeBh.toStringAsFixed(1)}  '
        '洞(未旋转): ${(holeW * k).toStringAsFixed(1)} x ${(holeH * k).toStringAsFixed(1)}');

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: landW,
              height: landH,
              color: const Color(0xFFCCCCCC),
              child: Stack(
                children: [
                  Positioned(
                    left: holeCx - holeBw / 2,
                    top: holeCy - holeBh / 2,
                    width: holeBw,
                    height: holeBh,
                    child: ClipPath(
                      clipper: ScreenHoleClipper(
                        width: holeW * k,
                        height: holeH * k,
                        angle: angle,
                        radius: cornerR * sInner * k,
                      ),
                      child: const CustomPaint(painter: _HalfPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/holeclip_test.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}

class _HalfPainter extends CustomPainter {
  const _HalfPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height),
        Paint()..color = const Color(0xFFFF0000));
    canvas.drawRect(Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
        Paint()..color = const Color(0xFF0000FF));
  }

  @override
  bool shouldRepaint(_HalfPainter old) => false;
}
