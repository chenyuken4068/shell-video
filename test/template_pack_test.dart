import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shell_video_app/models/shell_template.dart';
import 'package:shell_video_app/services/template_pack.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pack_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> makePng(int w, int h) async {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(200, 200, 210));
    final file = File(p.join(tmp.path, 'src_${w}x$h.png'));
    await file.writeAsBytes(img.encodePng(im));
    return file.path;
  }

  /// 手工造一个包（用于构造各种异常情况）
  Future<String> makePack(
    Map<String, dynamic> meta, {
    Uint8List? image,
    String imageEntry = TemplatePack.imageName,
  }) async {
    final jb = utf8.encode(jsonEncode(meta));
    final a = Archive()..addFile(ArchiveFile(TemplatePack.jsonName, jb.length, jb));
    if (image != null) {
      a.addFile(ArchiveFile(imageEntry, image.length, image));
    }
    final out = File(p.join(tmp.path, 'pack_${DateTime.now().microsecondsSinceEpoch}.zip'));
    await out.writeAsBytes(ZipEncoder().encode(a)!);
    return out.path;
  }

  Map<String, dynamic> metaOf({
    String name = '小明的壳',
    int w = 300,
    int h = 600,
    int x = 20,
    int y = 30,
    int sw = 200,
    int sh = 500,
    int r = 24,
    bool transparent = true,
  }) =>
      {
        'format': 1,
        'kind': 'shell_template',
        'name': name,
        'caseWidth': w,
        'caseHeight': h,
        'screenX': x,
        'screenY': y,
        'screenW': sw,
        'screenH': sh,
        'cornerR': r,
        'isTransparent': transparent,
        'image': TemplatePack.imageName,
      };

  test('打包 → 解析：字段一致', () async {
    final src = await makePng(300, 600);
    final t = ShellTemplate(
      id: 't1',
      name: '小明的壳',
      casePath: src,
      caseWidth: 300,
      caseHeight: 600,
      screenX: 20,
      screenY: 30,
      screenW: 200,
      screenH: 500,
      cornerR: 24,
      isTransparent: true,
    );
    final pack = p.join(tmp.path, 'a.zip');
    await TemplatePack.write(t, pack);
    expect(await File(pack).exists(), isTrue);
    expect(p.basename(pack), 'a.zip');

    final data = await TemplatePack.parse(pack, workDir: p.join(tmp.path, 'work'));
    expect(data.name, '小明的壳');
    expect(data.caseWidth, 300);
    expect(data.caseHeight, 600);
    expect(data.screenX, 20);
    expect(data.screenY, 30);
    expect(data.screenW, 200);
    expect(data.screenH, 500);
    expect(data.cornerR, 24);
    expect(data.isTransparent, isTrue);
    expect(await File(data.imagePath).exists(), isTrue);
  });

  test('不是 zip 的文件 → 明确报错', () async {
    final bad = File(p.join(tmp.path, 'bad.zip'));
    await bad.writeAsBytes(Uint8List.fromList(List<int>.filled(500, 7)));
    await expectLater(
      TemplatePack.parse(bad.path, workDir: tmp.path),
      throwsA(isA<TemplatePackException>()),
    );
  });

  test('缺少图片 → 报错', () async {
    final pack = await makePack(metaOf());
    await expectLater(
      TemplatePack.parse(pack, workDir: tmp.path),
      throwsA(isA<TemplatePackException>()),
    );
  });

  test('格式版本不支持 → 报错', () async {
    final src = await makePng(100, 200);
    final bytes = await File(src).readAsBytes();
    final meta = metaOf(w: 100, h: 200, sw: 80, sh: 180)..['format'] = 99;
    final pack = await makePack(meta, image: bytes);
    await expectLater(
      TemplatePack.parse(pack, workDir: tmp.path),
      throwsA(isA<TemplatePackException>()),
    );
  });

  test('越界坐标被夹回图内', () async {
    final src = await makePng(100, 200);
    final bytes = await File(src).readAsBytes();
    final meta = metaOf(w: 100, h: 200, x: 80, y: 190, sw: 500, sh: 500)
      ..['cornerR'] = 999;
    final pack = await makePack(meta, image: bytes);
    final data = await TemplatePack.parse(pack, workDir: tmp.path);
    expect(data.screenX, 80);
    expect(data.screenY, 190);
    expect(data.screenW, 20); // 100 - 80
    expect(data.screenH, 10); // 200 - 190
    expect(data.cornerR, lessThanOrEqualTo(5));
  });

  test('以图片真实尺寸为准（包里数字撒谎）', () async {
    final src = await makePng(120, 240);
    final bytes = await File(src).readAsBytes();
    // 包里声称 3000×3000
    final meta = metaOf(w: 3000, h: 3000, sw: 100, sh: 200);
    final pack = await makePack(meta, image: bytes);
    final data = await TemplatePack.parse(pack, workDir: tmp.path);
    expect(data.caseWidth, 120);
    expect(data.caseHeight, 240);
  });

  test('名字里的路径字符被清理 / 空名有兜底', () async {
    final src = await makePng(60, 120);
    final bytes = await File(src).readAsBytes();
    final meta = metaOf(name: '../../etc/pa:ss', w: 60, h: 120, sw: 40, sh: 100);
    final pack = await makePack(meta, image: bytes);
    final data = await TemplatePack.parse(pack, workDir: tmp.path);
    expect(data.name.contains('/'), isFalse);
    expect(data.name.contains(':'), isFalse);
    expect(data.name.length, lessThanOrEqualTo(40));
  });
}
