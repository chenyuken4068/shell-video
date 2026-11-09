/// 手机壳模板：壳图 + 屏幕区域参数
class ShellTemplate {
  final String id;
  final String name;
  final String casePath; // 壳图绝对路径
  final int caseWidth;
  final int caseHeight;
  final int screenX;
  final int screenY;
  final int screenW;
  final int screenH;
  final int cornerR; // 屏幕圆角半径
  final bool builtIn;
  /// true = 全透明模板（屏幕区域透明，无需抠图，可带背景）
  final bool isTransparent;

  const ShellTemplate({
    required this.id,
    required this.name,
    required this.casePath,
    required this.caseWidth,
    required this.caseHeight,
    required this.screenX,
    required this.screenY,
    required this.screenW,
    required this.screenH,
    required this.cornerR,
    this.builtIn = false,
    this.isTransparent = false,
  });

  ShellTemplate copyWith({
    String? name,
    String? casePath,
    int? caseWidth,
    int? caseHeight,
    int? screenX,
    int? screenY,
    int? screenW,
    int? screenH,
    int? cornerR,
    bool? isTransparent,
  }) {
    return ShellTemplate(
      id: id,
      name: name ?? this.name,
      casePath: casePath ?? this.casePath,
      caseWidth: caseWidth ?? this.caseWidth,
      caseHeight: caseHeight ?? this.caseHeight,
      screenX: screenX ?? this.screenX,
      screenY: screenY ?? this.screenY,
      screenW: screenW ?? this.screenW,
      screenH: screenH ?? this.screenH,
      cornerR: cornerR ?? this.cornerR,
      builtIn: builtIn,
      isTransparent: isTransparent ?? this.isTransparent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'casePath': casePath,
        'caseWidth': caseWidth,
        'caseHeight': caseHeight,
        'screenX': screenX,
        'screenY': screenY,
        'screenW': screenW,
        'screenH': screenH,
        'cornerR': cornerR,
        'builtIn': builtIn,
        'isTransparent': isTransparent,
      };

  factory ShellTemplate.fromJson(Map<String, dynamic> json) {
    return ShellTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      casePath: json['casePath'] as String,
      caseWidth: (json['caseWidth'] as num).toInt(),
      caseHeight: (json['caseHeight'] as num).toInt(),
      screenX: (json['screenX'] as num).toInt(),
      screenY: (json['screenY'] as num).toInt(),
      screenW: (json['screenW'] as num).toInt(),
      screenH: (json['screenH'] as num).toInt(),
      cornerR: (json['cornerR'] as num).toInt(),
      builtIn: json['builtIn'] as bool? ?? false,
      isTransparent: json['isTransparent'] as bool? ?? false,
    );
  }

  String describe() {
    return '屏幕区域 x=$screenX y=$screenY ${screenW}x$screenH 圆角R=$cornerR';
  }

  /// 复制一份模板，只替换壳图路径（多颜色切换用）
  ShellTemplate withCasePath(String path) => ShellTemplate(
        id: id,
        name: name,
        casePath: path,
        caseWidth: caseWidth,
        caseHeight: caseHeight,
        screenX: screenX,
        screenY: screenY,
        screenW: screenW,
        screenH: screenH,
        cornerR: cornerR,
        builtIn: builtIn,
        isTransparent: isTransparent,
      );
}
