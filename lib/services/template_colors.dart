/// 颜色变体表（OPPO / vivo 多配色模板）
///
/// key = 该机型最亮（白/浅色）颜色的 templateId —— 也是模板库默认进入的颜色
/// ColorVariant.color 取自「正反图」背面实测颜色
class ColorVariant {
  final String name;
  final String templateId;
  final int color;
  const ColorVariant(this.name, this.templateId, this.color);
}

/// 机型 → 全部配色（第一个 = 默认）
const Map<String, List<ColorVariant>> kColorVariants = {
  // ── Find X10 Pro Max ──
  'builtin_oppo_findx10promax_moonwhite': [
    ColorVariant('月白', 'builtin_oppo_findx10promax_moonwhite', 0xFFEDEDED),
    ColorVariant('暖橙', 'builtin_oppo_findx10promax_warmorange', 0xFFFEC1A7),
    ColorVariant('浅钛', 'builtin_oppo_findx10promax_lighttitanium', 0xFFA49EA1),
  ],
  // ── Find X8 ──
  'builtin_oppo_findx8_white': [
    ColorVariant('浮光白', 'builtin_oppo_findx8_white', 0xFFE4E5E5),
    ColorVariant('气泡粉', 'builtin_oppo_findx8_pink', 0xFFEDDFE0),
    ColorVariant('追风蓝', 'builtin_oppo_findx8_blue', 0xFFA9B9D0),
    ColorVariant('星野黑', 'builtin_oppo_findx8_black', 0xFF353537),
  ],
  // ── Find X8 Ultra ──
  'builtin_oppo_findx8ultra_dawn': [
    ColorVariant('晨曦微光', 'builtin_oppo_findx8ultra_dawn', 0xFFF6E1E4),
    ColorVariant('月光白', 'builtin_oppo_findx8ultra_moonwhite2', 0xFFDAD7D2),
    ColorVariant('星野黑', 'builtin_oppo_findx8ultra_black', 0xFF3F4041),
  ],
  // ── Find X8s ──
  'builtin_oppo_findx8s_sakura': [
    ColorVariant('落樱粉', 'builtin_oppo_findx8s_sakura', 0xFFF5E2E6),
    ColorVariant('月光白', 'builtin_oppo_findx8s_moonwhite2', 0xFFE3E1DC),
    ColorVariant('海岛蓝', 'builtin_oppo_findx8s_islandblue', 0xFFBDCEE3),
    ColorVariant('星野黑', 'builtin_oppo_findx8s_black', 0xFF404143),
  ],
  // ── Find X9 ──
  'builtin_oppo_findx9_frostwhite': [
    ColorVariant('霜白', 'builtin_oppo_findx9_frostwhite', 0xFFEDECEC),
    ColorVariant('绒光钛', 'builtin_oppo_findx9_titanium', 0xFFA5A1A3),
    ColorVariant('追光红', 'builtin_oppo_findx9_red', 0xFF9C3859),
    ColorVariant('雾黑', 'builtin_oppo_findx9_fogblack', 0xFF333436),
  ],
  // ── Find X9 Pro ──
  'builtin_oppo_findx9pro_frostwhite': [
    ColorVariant('霜白', 'builtin_oppo_findx9pro_frostwhite', 0xFFDEDFDB),
    ColorVariant('绒光钛', 'builtin_oppo_findx9pro_titanium', 0xFF5A5455),
    ColorVariant('追光红', 'builtin_oppo_findx9pro_red', 0xFF882B49),
  ],
  // ── Find X9 Ultra ──
  'builtin_oppo_findx9ultra_glacier': [
    ColorVariant('极地冰川', 'builtin_oppo_findx9ultra_glacier', 0xFFE1E1E1),
    ColorVariant('绒砂峡谷', 'builtin_oppo_findx9ultra_canyon', 0xFFF08855),
    ColorVariant('大地苔原', 'builtin_oppo_findx9ultra_tundra', 0xFF313131),
  ],
  // ── Find X9S Pro ──
  'builtin_oppo_findx9spro_freewhite': [
    ColorVariant('自在白', 'builtin_oppo_findx9spro_freewhite', 0xFFD9D6DE),
    ColorVariant('乘风青', 'builtin_oppo_findx9spro_cyan', 0xFF7FE2E0),
    ColorVariant('元气橙', 'builtin_oppo_findx9spro_orange', 0xFFECB59B),
    ColorVariant('原生钛', 'builtin_oppo_findx9spro_nativetitanium', 0xFF605859),
  ],
  // ── vivo X100 ──
  'builtin_vivo_vivox100_v1': [
    ColorVariant('白月光', 'builtin_vivo_vivox100_v1', 0xFFECECEC),
    ColorVariant('星迹蓝', 'builtin_vivo_vivox100_v0', 0xFFA8CED7),
    ColorVariant('落日橙', 'builtin_vivo_vivox100_v2', 0xFFC7561C),
    ColorVariant('辰夜黑', 'builtin_vivo_vivox100_v3', 0xFF252729),
  ],
  // ── vivo X200 Pro mini ──
  'builtin_vivo_vivox200promini_v6': [
    ColorVariant('直白', 'builtin_vivo_vivox200promini_v6', 0xFFF0F0F0),
    ColorVariant('微粉', 'builtin_vivo_vivox200promini_v4', 0xFFEEDBDE),
    ColorVariant('淡紫', 'builtin_vivo_vivox200promini_v5', 0xFFDDD8E7),
    ColorVariant('钛青', 'builtin_vivo_vivox200promini_v8', 0xFF9AA79B),
    ColorVariant('简黑', 'builtin_vivo_vivox200promini_v7', 0xFF2E3136),
  ],
  // ── vivo X300 ──
  'builtin_vivo_vivox300_v10': [
    ColorVariant('幸运彩', 'builtin_vivo_vivox300_v10', 0xFFF2EAE2),
    ColorVariant('自在蓝', 'builtin_vivo_vivox300_v13', 0xFFD7E6EB),
    ColorVariant('惬意紫', 'builtin_vivo_vivox300_v11', 0xFFABA3AF),
    ColorVariant('纯粹黑', 'builtin_vivo_vivox300_v12', 0xFF4A4A4A),
    ColorVariant('好运红', 'builtin_vivo_vivox300_v9', 0xFF66272B),
  ],
  // ── vivo X300 Pro ──
  'builtin_vivo_vivox300pro_v15': [
    ColorVariant('简单白', 'builtin_vivo_vivox300pro_v15', 0xFFE5E5E3),
    ColorVariant('自在蓝', 'builtin_vivo_vivox300pro_v17', 0xFFD7E6EB),
    ColorVariant('旷野棕', 'builtin_vivo_vivox300pro_v14', 0xFFD0CABD),
    ColorVariant('纯粹黑', 'builtin_vivo_vivox300pro_v16', 0xFF3E3E3E),
  ],
  // ── vivo X300 Ultra ──
  'builtin_vivo_vivox300ultra_v19': [
    ColorVariant('银调', 'builtin_vivo_vivox300ultra_v19', 0xFFF3F3F3),
    ColorVariant('胶片绿', 'builtin_vivo_vivox300ultra_v18', 0xFFD2DAC3),
    ColorVariant('黑Ka', 'builtin_vivo_vivox300ultra_v20', 0xFF464648),
  ],
  // ── vivo X500 ──
  'builtin_vivo_vivox500_v24': [
    ColorVariant('晴天', 'builtin_vivo_vivox500_v24', 0xFFF2F6F4),
    ColorVariant('晨曦', 'builtin_vivo_vivox500_v23', 0xFFEEE1E9),
    ColorVariant('大地回声', 'builtin_vivo_vivox500_v21', 0xFF9A9FA6),
    ColorVariant('摄夜', 'builtin_vivo_vivox500_v22', 0xFF323538),
  ],
};

/// 模板库展示图（正反图）: templateId → assets 路径
const Map<String, String> kTemplateDisplayFile = {
  'builtin_oppo_findx10promax_warmorange': 'assets/templates/oppo_findx10promax_warmorange_display.png',
  'builtin_oppo_findx10promax_moonwhite': 'assets/templates/oppo_findx10promax_moonwhite_display.png',
  'builtin_oppo_findx10promax_lighttitanium': 'assets/templates/oppo_findx10promax_lighttitanium_display.png',
  'builtin_oppo_findx2_c3': 'assets/templates/oppo_findx2_c3_display.png',
  'builtin_oppo_findx3_c4': 'assets/templates/oppo_findx3_c4_display.png',
  'builtin_oppo_findx5_c5': 'assets/templates/oppo_findx5_c5_display.png',
  'builtin_oppo_findx6_c6': 'assets/templates/oppo_findx6_c6_display.png',
  'builtin_oppo_findx7_c7': 'assets/templates/oppo_findx7_c7_display.png',
  'builtin_oppo_findx8_black': 'assets/templates/oppo_findx8_black_display.png',
  'builtin_oppo_findx8_pink': 'assets/templates/oppo_findx8_pink_display.png',
  'builtin_oppo_findx8_white': 'assets/templates/oppo_findx8_white_display.png',
  'builtin_oppo_findx8_blue': 'assets/templates/oppo_findx8_blue_display.png',
  'builtin_oppo_findx8ultra_black': 'assets/templates/oppo_findx8ultra_black_display.png',
  'builtin_oppo_findx8ultra_dawn': 'assets/templates/oppo_findx8ultra_dawn_display.png',
  'builtin_oppo_findx8ultra_moonwhite2': 'assets/templates/oppo_findx8ultra_moonwhite2_display.png',
  'builtin_oppo_findx8s_black': 'assets/templates/oppo_findx8s_black_display.png',
  'builtin_oppo_findx8s_moonwhite2': 'assets/templates/oppo_findx8s_moonwhite2_display.png',
  'builtin_oppo_findx8s_islandblue': 'assets/templates/oppo_findx8s_islandblue_display.png',
  'builtin_oppo_findx8s_sakura': 'assets/templates/oppo_findx8s_sakura_display.png',
  'builtin_oppo_findx9_titanium': 'assets/templates/oppo_findx9_titanium_display.png',
  'builtin_oppo_findx9_red': 'assets/templates/oppo_findx9_red_display.png',
  'builtin_oppo_findx9_fogblack': 'assets/templates/oppo_findx9_fogblack_display.png',
  'builtin_oppo_findx9_frostwhite': 'assets/templates/oppo_findx9_frostwhite_display.png',
  'builtin_oppo_findx9pro_titanium': 'assets/templates/oppo_findx9pro_titanium_display.png',
  'builtin_oppo_findx9pro_red': 'assets/templates/oppo_findx9pro_red_display.png',
  'builtin_oppo_findx9pro_frostwhite': 'assets/templates/oppo_findx9pro_frostwhite_display.png',
  'builtin_oppo_findx9ultra_tundra': 'assets/templates/oppo_findx9ultra_tundra_display.png',
  'builtin_oppo_findx9ultra_glacier': 'assets/templates/oppo_findx9ultra_glacier_display.png',
  'builtin_oppo_findx9ultra_canyon': 'assets/templates/oppo_findx9ultra_canyon_display.png',
  'builtin_oppo_findx9spro_cyan': 'assets/templates/oppo_findx9spro_cyan_display.png',
  'builtin_oppo_findx9spro_orange': 'assets/templates/oppo_findx9spro_orange_display.png',
  'builtin_oppo_findx9spro_nativetitanium': 'assets/templates/oppo_findx9spro_nativetitanium_display.png',
  'builtin_oppo_findx9spro_freewhite': 'assets/templates/oppo_findx9spro_freewhite_display.png',
  'builtin_vivo_vivox100_v1': 'assets/templates/vivo_vivox100_v1_display.png',
  'builtin_vivo_vivox100_v0': 'assets/templates/vivo_vivox100_v0_display.png',
  'builtin_vivo_vivox100_v2': 'assets/templates/vivo_vivox100_v2_display.png',
  'builtin_vivo_vivox100_v3': 'assets/templates/vivo_vivox100_v3_display.png',
  'builtin_vivo_vivox200promini_v6': 'assets/templates/vivo_vivox200promini_v6_display.png',
  'builtin_vivo_vivox200promini_v4': 'assets/templates/vivo_vivox200promini_v4_display.png',
  'builtin_vivo_vivox200promini_v5': 'assets/templates/vivo_vivox200promini_v5_display.png',
  'builtin_vivo_vivox200promini_v8': 'assets/templates/vivo_vivox200promini_v8_display.png',
  'builtin_vivo_vivox200promini_v7': 'assets/templates/vivo_vivox200promini_v7_display.png',
  'builtin_vivo_vivox300_v10': 'assets/templates/vivo_vivox300_v10_display.png',
  'builtin_vivo_vivox300_v13': 'assets/templates/vivo_vivox300_v13_display.png',
  'builtin_vivo_vivox300_v11': 'assets/templates/vivo_vivox300_v11_display.png',
  'builtin_vivo_vivox300_v12': 'assets/templates/vivo_vivox300_v12_display.png',
  'builtin_vivo_vivox300_v9': 'assets/templates/vivo_vivox300_v9_display.png',
  'builtin_vivo_vivox300pro_v15': 'assets/templates/vivo_vivox300pro_v15_display.png',
  'builtin_vivo_vivox300pro_v17': 'assets/templates/vivo_vivox300pro_v17_display.png',
  'builtin_vivo_vivox300pro_v14': 'assets/templates/vivo_vivox300pro_v14_display.png',
  'builtin_vivo_vivox300pro_v16': 'assets/templates/vivo_vivox300pro_v16_display.png',
  'builtin_vivo_vivox300ultra_v19': 'assets/templates/vivo_vivox300ultra_v19_display.png',
  'builtin_vivo_vivox300ultra_v18': 'assets/templates/vivo_vivox300ultra_v18_display.png',
  'builtin_vivo_vivox300ultra_v20': 'assets/templates/vivo_vivox300ultra_v20_display.png',
  'builtin_vivo_vivox500_v24': 'assets/templates/vivo_vivox500_v24_display.png',
  'builtin_vivo_vivox500_v23': 'assets/templates/vivo_vivox500_v23_display.png',
  'builtin_vivo_vivox500_v21': 'assets/templates/vivo_vivox500_v21_display.png',
  'builtin_vivo_vivox500_v22': 'assets/templates/vivo_vivox500_v22_display.png',
};
