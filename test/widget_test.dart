import 'package:flutter_test/flutter_test.dart';

import 'package:shell_video_app/models/shell_template.dart';

void main() {
  test('模板序列化往返', () {
    const t = ShellTemplate(
      id: 't1',
      name: '小米14',
      casePath: '/tmp/x.png',
      caseWidth: 1397,
      caseHeight: 2984,
      screenX: 95,
      screenY: 157,
      screenW: 1198,
      screenH: 2669,
      cornerR: 132,
      builtIn: true,
    );
    final restored = ShellTemplate.fromJson(t.toJson());
    expect(restored.id, t.id);
    expect(restored.name, t.name);
    expect(restored.screenW, t.screenW);
    expect(restored.cornerR, t.cornerR);
  });

  test('模板描述信息', () {
    const t = ShellTemplate(
      id: 't1',
      name: '小米14',
      casePath: '/tmp/x.png',
      caseWidth: 1397,
      caseHeight: 2984,
      screenX: 95,
      screenY: 157,
      screenW: 1198,
      screenH: 2669,
      cornerR: 132,
    );
    expect(t.describe(), contains('1198'));
  });
}
