import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shell_video_app/models/shell_template.dart';
import 'package:shell_video_app/screens/tpl_library_screen.dart';
import 'package:shell_video_app/services/template_store.dart';

/// 内存版数据源，规避测试环境的文件 IO 限制
class _FakeStore extends TemplateStore {
  @override
  Future<List<ShellTemplate>> load() async => [];
}

/// 带两条自制模板的数据源：一条抠图、一条透明
class _FakeStoreWithData extends TemplateStore {
  @override
  Future<List<ShellTemplate>> load() async => const [
        ShellTemplate(
          id: 'c1',
          name: '我的抠图壳',
          casePath: '/tmp/a.png',
          caseWidth: 1000,
          caseHeight: 2000,
          screenX: 50,
          screenY: 60,
          screenW: 900,
          screenH: 1800,
          cornerR: 90,
        ),
        ShellTemplate(
          id: 'c2',
          name: '我的透明壳',
          casePath: '/tmp/b.png',
          caseWidth: 1000,
          caseHeight: 2000,
          screenX: 50,
          screenY: 60,
          screenW: 900,
          screenH: 1800,
          cornerR: 90,
          isTransparent: true,
        ),
      ];
}

void main() {
  testWidgets('模板库：chips 分组 + 空态引导 + 品牌机型卡', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TplLibraryScreen(store: _FakeStore())),
    );
    await tester.pumpAndSettle();

    // 顶栏
    expect(find.text('模板库'), findsOneWidget);
    // 悬浮底栏：自制（抠图+透明合并）+ 小米 + 其他
    expect(find.text('自制'), findsWidgets);
    expect(find.text('小米'), findsWidgets);
    expect(find.text('其他'), findsWidgets);
    // 其余分组在「其他」弹出卡片里
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    for (final g in ['常用', '华为', 'OPPO', 'vivo', '三星', '荣耀']) {
      expect(find.text(g), findsWidgets);
    }
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    // 旧的「标定透明模板」卡片已移除
    expect(find.textContaining('标定透明模板'), findsNothing);

    // 默认在「自制」，测试数据源为空 → 合并空态引导
    expect(find.text('还没有自制模板'), findsOneWidget);


    // 切换品牌：华为
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('华为'));
    await tester.pump();
    expect(find.textContaining('Mate 90'), findsOneWidget);
    expect(find.textContaining('Mate 80'), findsOneWidget);
    expect(find.textContaining('Mate 70'), findsOneWidget);
    // Mate 60 是品牌页最后一张，ListView 懒加载可能还没构建 → 先滚动再断言
    await tester.drag(find.byType(ListView).last, const Offset(0, -360));
    await tester.pump();
    expect(find.textContaining('Mate 60'), findsOneWidget);
  });

  testWidgets('模板库：自制分组合并展示抠图与透明模板（带标签）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TplLibraryScreen(store: _FakeStoreWithData())),
    );
    await tester.pumpAndSettle();

    // 合并分组：两条自制模板都显示
    expect(find.text('我的抠图壳'), findsOneWidget);
    expect(find.text('我的透明壳'), findsOneWidget);
    // 卡片右上角标签区分类型
    expect(find.text('抠图'), findsOneWidget);
    expect(find.text('透明'), findsOneWidget);
  });
}
