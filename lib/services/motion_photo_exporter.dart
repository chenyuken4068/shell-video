import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';

/// 把「合成好的 MP4 + 封面帧 JPEG」打包成 OPPO 变体动态照片
/// （小米已实测识别 ✓）
///
/// 结构 = JPEG(带 XMP + GainMap + 尾部 MP4)
///   XMP：GCamera:MotionPhoto + OpCamera 私有字段
///   Container：Primary（Length=0）+ GainMap（占位，复用同一张 JPEG）+ MotionPhoto（mp4）
class MotionPhotoExporter {
  static const _prefix = 'http://ns.adobe.com/xap/1.0/\x00';

  /// 生成动态照片文件，返回路径
  static Future<String> build({
    required String videoPath,
    required String jpegPath,
    required String outPath,
    int coverMs = 0,
  }) async {
    final jpeg = await File(jpegPath).readAsBytes();
    final mp4 = await File(videoPath).readAsBytes();

    // GainMap 占位：复用同一张 JPEG（相册只认结构，不校验增益图内容）
    final gain = jpeg;

    final xmp = _oppoXmp(
      gainLen: gain.length,
      mp4Len: mp4.length,
      coverUs: coverMs <= 0 ? 0 : coverMs * 1000,
    );
    final payload = <int>[
      ...utf8.encode(_prefix),
      ...utf8.encode(xmp),
    ];

    // APP1 段：FFE1 + 长度(2 字节，含自身) + payload
    final app1 = BytesBuilder()
      ..addByte(0xFF)
      ..addByte(0xE1)
      ..addByte(((payload.length + 2) >> 8) & 0xFF)
      ..addByte((payload.length + 2) & 0xFF)
      ..add(payload);

    final primary = BytesBuilder()
      ..add(jpeg.sublist(0, 2)) // SOI
      ..add(app1.toBytes())
      ..add(jpeg.sublist(2));

    final out = BytesBuilder()
      ..add(primary.toBytes())
      ..add(gain)
      ..add(mp4);

    final f = File(outPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(out.toBytes(), flush: true);
    return outPath;
  }

  /// 保存到相册（动态照片按图片类型入库）
  static Future<void> saveToGallery(String path) async {
    final ok = await Gal.requestAccess(toAlbum: false);
    if (!ok) throw Exception('没有相册权限，请到系统设置里允许访问照片');
    await Gal.putImage(path);
  }

  static String _oppoXmp({
    required int gainLen,
    required int mp4Len,
    required int coverUs,
  }) {
    final ts = coverUs <= 0 ? 0 : coverUs;
    return '''<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
        xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
        xmlns:OpCamera="http://ns.oplus.com/photos/1.0/camera/"
        xmlns:Container="http://ns.google.com/photos/1.0/container/"
        xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
        xmlns:hdrgm="http://ns.adobe.com/hdr-gain-map/1.0/"
      hdrgm:Version="1.0"
      GCamera:MotionPhoto="1"
      GCamera:MotionPhotoVersion="1"
      GCamera:MotionPhotoPresentationTimestampUs="$ts"
      OpCamera:MotionPhotoPrimaryPresentationTimestampUs="$ts"
      OpCamera:MotionPhotoOwner="oplus"
      OpCamera:OLivePhotoVersion="2"
      OpCamera:VideoLength="$mp4Len">
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="image/jpeg"
              Item:Semantic="Primary"
              Item:Length="0"
              Item:Padding="0"/>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="image/jpeg"
              Item:Semantic="GainMap"
              Item:Length="$gainLen"
              Item:Padding="0"/>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="video/mp4"
              Item:Semantic="MotionPhoto"
              Item:Length="$mp4Len"
              Item:Padding="0"/>
          </rdf:li>
        </rdf:Seq>
      </Container:Directory>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
  }
}
