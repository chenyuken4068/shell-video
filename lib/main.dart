import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';

import 'services/app_log.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';

import 'widgets/boot_splash.dart';
import 'widgets/main_shell.dart';

import 'services/template_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.install();

  // 初始化模板库（首启复制内置壳图）
  try {
    await TemplateStore().init();
  final settings = await SettingsStore().load();
  gNavGlass.value = settings.navGlass;
  gNavGlassOpacity.value = settings.navGlassOpacity;
  gTplGroups.value = settings.tplGroups;
  gTplHidden.value = settings.tplHidden;
  gHomeOrder.value = settings.homeOrder;
  gHomeHidden.value = settings.homeHidden;
  gThemeMode.value = AppTheme.parse(settings.themeMode);
  AppTheme.current = gThemeMode.value;
  } catch (e) {
    debugPrint('模板库初始化失败: $e');
  }

  // FFmpeg 全局日志（仅调试输出，避免静默）
  FFmpegKitConfig.enableLogCallback((log) {
    debugPrint('[ffmpeg] ${log.getMessage()}');
  });

  runApp(const ShellVideoApp());
}

class ShellVideoApp extends StatelessWidget {
  const ShellVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: gThemeMode,
      builder: (context, mode, _) {
        AppTheme.current = mode;
        return MaterialApp(
          title: '壳映',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const BootSplash(child: MainShell()),
        );
      },
    );
  }
}
