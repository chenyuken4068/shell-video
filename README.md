# 壳映 ShellVideo

Flutter 短视频 / 图片套壳合成工具：把图片、视频、实况照片套进手机壳，导出带壳成品。

## 功能

- 多颜色模板（OPPO / vivo 共 33 色，可切换配色）
- 背景：纯色 / 背景图 / 素材自动取色 + 高斯模糊（0~100 可调）
- 视频、图片、实况、长截图四种创作模式
- 图库批量选择（长按触发）：全选 / 下载 / 分享 / 删除
- 模板库分组、自制模板、屏幕框自动标定

## 开发

```bash
flutter pub get
flutter run
```

## 构建 APK

```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

## 发布新版本（自动更新）

1. 修改 `pubspec.yaml` 的 `version: 3.3.1+331`
2. 修改 `version.json` 的 version / build / notes / apkUrl
3. 提交并打 tag：

```bash
git add -A
git commit -m "release: v3.3.1"
git tag v3.3.1
git push origin main --tags
```

4. GitHub Actions 会自动构建 APK 并创建 Release
5. App 内「我的 → 版本更新」会读取 `version.json` 并提示更新

## 创作者

- 酷安@真不叫地主 · 开发者
- 酷安@SOCMTK9300 · 模板库提供