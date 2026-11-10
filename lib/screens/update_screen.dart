import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_log.dart';
import '../theme/app_theme.dart';

/// 远程更新清单地址（多源容错，国内网络自动降级）
///
/// 说明：raw.githubusercontent.com / github.com 在国内经常超时，
/// 这里按「国内可达性」排序依次尝试：
///   ① api.github.com（内容 API，最稳）
///   ② gcore.jsdelivr.net（CDN 镜像）
///   ③ fastly.jsdelivr.net（CDN 备用）
///   ④ raw.githubusercontent.com（直连，海外/兜底）
const String kGithubOwner = 'chenyuken4068';
const String kGithubRepo = 'shell-video';
const String kVersionJsonUrl =
    'https://raw.githubusercontent.com/chenyuken4068/shell-video/main/version.json';

/// APK 下载代理（GitHub 直链在国内不可达时自动走这里）
const String kApkProxy = 'https://gh-proxy.com/';

String _apiContentsUrl() =>
    'https://api.github.com/repos/$kGithubOwner/$kGithubRepo/contents/version.json';
String _jsdelivrUrl(String host) =>
    'https://$host/gh/$kGithubOwner/$kGithubRepo@main/version.json';

/// 把 github.com 链接转成可用的代理链接（国内网络用）
String proxiedUrl(String url) {
  if (!url.contains('github.com')) return url;
  if (url.startsWith(kApkProxy)) return url;
  return kApkProxy + url;
}

/// 兜底：远程清单拉取失败时视为已是最新（留空 = 不提示更新）
const String kRemoteLatestVersion = '';

/// 版本更新页（二级页面）：参考 ColorOS / HyperOS 更新页
/// 两种状态：有新版本（Hero + 更新内容 + 立即更新）/ 已是最新（勾 + 版本信息 + 检查更新）
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _checking = true;
  String _current = '';
  String _build = '';
  String _latest = '';
  String _lastCheck = '';
  String _apkUrl = '';
  String _size = '';
  List<(String, String)> _remoteNotes = const [];
  bool _netError = false;

  /// 当前版本更新内容（内置 changelog：新增 / 优化 / 修复）
  static const List<(String, String)> _changelog = [
    ('新增', '多颜色模板（OPPO / vivo 共 33 色）'),
    ('新增', '背景自动取色 + 0~100 高斯模糊'),
    ('新增', '实况照片预览播放'),
    ('新增', '模板库自制分组合并 + 类型标签'),
    ('优化', '屏幕框标定算法（贴合更准）'),
    ('优化', '比例切换改为同画布连续缩放'),
    ('修复', '若干细节问题'),
  ];

  bool get _hasUpdate =>
      _latest.isNotEmpty && _current.isNotEmpty && _latest != _current;

  @override
  void initState() {
    super.initState();
    _check();
  }

  String _lastSource = '';

  /// 依次尝试多个源拉取版本清单；全部失败返回 null
  Future<Map<String, dynamic>?> _fetchManifest() async {
    // ① GitHub 内容 API（国内可达，返回 base64 内容）
    try {
      final body = await _get(_apiContentsUrl(), headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ShellVideoApp',
      });
      if (body != null) {
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (j['content'] is String) {
          final b64 = (j['content'] as String).replaceAll(RegExp(r"\s"), "");
          final txt = utf8.decode(base64Decode(b64));
          final m = jsonDecode(txt);
          if (m is Map<String, dynamic>) {
            _lastSource = 'api.github.com';
            return m;
          }
        }
      }
    } catch (e) {
      AppLog.i('api.github.com 失败: $e');
    }
    // ② jsDelivr CDN 镜像
    for (final host in const ['gcore.jsdelivr.net', 'fastly.jsdelivr.net']) {
      try {
        final body = await _get(_jsdelivrUrl(host));
        if (body != null) {
          final m = jsonDecode(body);
          if (m is Map<String, dynamic>) {
            _lastSource = host;
            return m;
          }
        }
      } catch (e) {
        AppLog.i('$host 失败: $e');
      }
    }
    // ③ raw 直连（海外兜底）
    try {
      final body = await _get(kVersionJsonUrl);
      if (body != null) {
        final m = jsonDecode(body);
        if (m is Map<String, dynamic>) {
          _lastSource = 'raw';
          return m;
        }
      }
    } catch (e) {
      AppLog.i('raw 失败: $e');
    }
    return null;
  }

  Future<String?> _get(String url, {Map<String, String>? headers}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'ShellVideoApp');
      headers?.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }


  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _check() async {
    _netError = false; // 每次检查前复位，避免上次失败一直显示「网络不可用」
    setState(() => _checking = true);
    String cur = '-';
    String build = '-';
    try {
      final info = await PackageInfo.fromPlatform();
      cur = info.version;
      build = info.buildNumber;
    } catch (_) {}
    // 拉取 GitHub 上的 version.json（失败则视为已是最新）
    String latest = kRemoteLatestVersion.isEmpty ? cur : kRemoteLatestVersion;
    String apkUrl = '';
    String size = '';
    List<(String, String)> notes = const [];
    final m = await _fetchManifest();
    if (m != null) {
      latest = (m['version'] as String?)?.trim().isNotEmpty == true
          ? m['version'] as String
          : latest;
      apkUrl = (m['apkUrl'] as String?) ?? '';
      size = (m['size'] as String?) ?? '';
      final raw = m['notes'];
      if (raw is List) {
        notes = raw
            .whereType<List>()
            .where((e) => e.length >= 2)
            .map((e) => (e[0].toString(), e[1].toString()))
            .toList();
      }
      AppLog.i('更新检查: 命中源=$_lastSource 版本=$latest');
    } else {
      AppLog.i('更新检查失败: 所有源都不可达');
      _netError = true;
    }
    if (!mounted) return;
    setState(() {
      _current = cur;
      _build = build;
      _latest = latest;
      _apkUrl = apkUrl;
      _size = size;
      _remoteNotes = notes;
      _lastCheck = _netError ? '网络不可用' : '刚刚';
      _checking = false;
      AppLog.i('更新检查: 当前=$cur 远程=$latest 网络错误=$_netError');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // 玻璃顶栏（同模板库 / 设置）
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_left,
                          size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('版本更新',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _checking
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        SizedBox(height: 12),
                        Text('正在检查更新…',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textSub)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _hero(),
                      _changelogCard(),
                      if (!_hasUpdate) ...[
                        const SizedBox(height: 4),
                        _versionCard(),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
          ),
          // 底部固定主按钮
          if (!_checking) _bottomButton(),
        ],
      ),
    );
  }

  Widget _hero() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B9BFF), Color(0xFF2F6BFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6BFF).withValues(alpha: .28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.smartphone, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 14),
        const Text('壳映 ShellVideo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hasUpdate ? _latest : _current,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent)),
            const SizedBox(width: 8),
            Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _hasUpdate
                    ? AppColors.accent.withValues(alpha: .12)
                    : const Color(0xFFE7F7EE),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                _hasUpdate ? '发现新版本' : '已是最新',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color:
                      _hasUpdate ? AppColors.accent : const Color(0xFF1E7B38),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _hasUpdate
              ? '当前版本 $_current · 可更新至 $_latest'
              : '当前版本 $_current（build $_build）· 上次检查：$_lastCheck',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSub),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<(String, String)> get _notes =>
      _remoteNotes.isNotEmpty ? _remoteNotes : _changelog;

  Widget _changelogCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hasUpdate ? '更新内容' : '本版本更新内容',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          for (int i = 0; i < _notes.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _notes.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC3C9D6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.55,
                          color: Color(0xFF3B4356),
                        ),
                        children: [
                          TextSpan(
                            text: '${_notes[i].$1} ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent),
                          ),
                          TextSpan(text: _notes[i].$2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _versionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),
      child: Column(
        children: [
          _infoRow('当前版本', '$_current (build $_build)'),
          _divider(),
          _infoRow('最新版本', _latest),
          _divider(),
          _infoRow('上次检查', _lastCheck),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(l,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            Text(r,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSub)),
          ],
        ),
      );

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF1F4F9));

  Widget _bottomButton() {
    final has = _hasUpdate;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        child: GestureDetector(
          onTap: has
              ? () async {
                  final url = _apkUrl.isNotEmpty
                      ? proxiedUrl(_apkUrl)
                      : proxiedUrl(
                          'https://github.com/chenyuken4068/shell-video/releases/latest');
                  try {
                    final ok = await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                    if (!ok && mounted) _toast('无法打开下载链接');
                  } catch (e) {
                    if (mounted) _toast('打开链接失败: $e');
                  }
                }
              : _check,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: has
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A90FF), Color(0xFF2F6BFF)],
                    )
                  : null,
              color: has ? null : AppColors.card,
              border: has
                  ? null
                  : Border.all(color: const Color(0xFFD7E5FF), width: 1.5),
              boxShadow: has
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2F6BFF).withValues(alpha: .30),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              has ? '立即更新' : '检查更新',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: has ? Colors.white : AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
