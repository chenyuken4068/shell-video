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
    // ── iQOO 15 ──
    'builtin_iqoo15_chuanqi': [
      ColorVariant('传奇版', 'builtin_iqoo15_chuanqi', 0xFFC8C8C8),
      ColorVariant('凌云', 'builtin_iqoo15_lingyun', 0xFF999D9F),
      ColorVariant('旷野', 'builtin_iqoo15_kuangye', 0xFFC0C6A3),
      ColorVariant('王者荣耀十周年典藏版', 'builtin_iqoo15_wangzhe', 0xFF6C6E71),
      ColorVariant('赛道版', 'builtin_iqoo15_saidao', 0xFF6B6D70),
    ],
    // ── iQOO 15 Ultra ──
    'builtin_iqoo15ultra_silver2049': [
      ColorVariant('2049银色', 'builtin_iqoo15ultra_silver2049', 0xFF72757D),
      ColorVariant('2077黑色', 'builtin_iqoo15ultra_black2077', 0xFF545557),
    ],
    // ── iQOO 16 ──
    'builtin_iqoo16_chuanqi': [
      ColorVariant('传奇', 'builtin_iqoo16_chuanqi', 0xFFC2C2C1),
      ColorVariant('赛道', 'builtin_iqoo16_saidao', 0xFF514F5F),
      ColorVariant('逐光', 'builtin_iqoo16_zhuguang', 0xFFC4C1BD),
    ],
    // ── 一加 16 ──
    'builtin_oneplus16_mingri': [
      ColorVariant('明日星光', 'builtin_oneplus16_mingri', 0xFF95989F),
      ColorVariant('火星杰作', 'builtin_oneplus16_huoxing', 0xFFD4A08D),
      ColorVariant('黑暗森林', 'builtin_oneplus16_heian', 0xFF4E525C),
    ],
    // ── 一加 15T ──
    'builtin_oneplus15t_zhiyu': [
      ColorVariant('治愈白巧', 'builtin_oneplus15t_zhiyu', 0xFFC8C8C3),
      ColorVariant('松弛抹茶', 'builtin_oneplus15t_songchi', 0xFF909D79),
      ColorVariant('纯粹可可', 'builtin_oneplus15t_chuncui', 0xFF564F50),
    ],
    // ── 一加 15 ──
    'builtin_oneplus15_yuansha': [
      ColorVariant('原色沙丘', 'builtin_oneplus15_yuansha', 0xFFB6ADA4),
      ColorVariant('绝对黑', 'builtin_oneplus15_juedui', 0xFF4B4E51),
      ColorVariant('雾光紫', 'builtin_oneplus15_wuguang', 0xFFA39AA9),
    ],
    // ── 一加 13T ──
    'builtin_oneplus13t_chenwu': [
      ColorVariant('晨雾灰', 'builtin_oneplus13t_chenwu', 0xFF94979C),
      ColorVariant('云墨黑', 'builtin_oneplus13t_yunmo', 0xFF4E4E4D),
      ColorVariant('怦然粉', 'builtin_oneplus13t_pengran', 0xFFAA9FA5),
    ],
    // ── 一加 13 ──
    'builtin_oneplus13_bailu': [
      ColorVariant('白露晨曦', 'builtin_oneplus13_bailu', 0xFF808080),
      ColorVariant('蓝调时刻', 'builtin_oneplus13_landiao', 0xFF828283),
      ColorVariant('黑曜秘境', 'builtin_oneplus13_heiyao', 0xFF757575),
    ],
    // ── 真我 GT8 Pro ──
    'builtin_realme_gt8pro_white': [
      ColorVariant('怀特', 'builtin_realme_gt8pro_white', 0xFF9E9E9C),
      ColorVariant('布鲁', 'builtin_realme_gt8pro_blue', 0xFF616A7C),
      ColorVariant('格林', 'builtin_realme_gt8pro_green', 0xFF92A099),
      ColorVariant('阿斯顿马丁绿', 'builtin_realme_gt8pro_amg', 0xFF539481),
    ],
    // ── 真我 GT8 ──
    'builtin_realme_gt8_white': [
      ColorVariant('怀特', 'builtin_realme_gt8_white', 0xFF9F9F9F),
      ColorVariant('格林', 'builtin_realme_gt8_green', 0xFF8D9F95),
      ColorVariant('纳维', 'builtin_realme_gt8_navy', 0xFF5C6479),
    ],
    // ── 三星 Galaxy S26 Ultra ──
    'builtin_samsung_s26u_xingshuang': [
      ColorVariant('星霜白', 'builtin_samsung_s26u_xingshuang', 0xFFAEAFB3),
      ColorVariant('星暮紫', 'builtin_samsung_s26u_xingmu', 0xFF585A7A),
      ColorVariant('星曜黑', 'builtin_samsung_s26u_xingyao', 0xFF45494D),
      ColorVariant('星月银', 'builtin_samsung_s26u_xingyue', 0xFF9FA0A3),
      ColorVariant('星澄蓝', 'builtin_samsung_s26u_xingcheng', 0xFFB5C2CF),
      ColorVariant('星瑰金', 'builtin_samsung_s26u_xinggui', 0xFFE5D6CD),
    ],
    // ── 三星 Galaxy S25 Ultra ──
    'builtin_samsung_s25u_tiyin': [
      ColorVariant('钛银蓝', 'builtin_samsung_s25u_tiyin', 0xFFAEAEB0),
      ColorVariant('钛墨黑', 'builtin_samsung_s25u_timo', 0xFF575A62),
      ColorVariant('钛影黑', 'builtin_samsung_s25u_tiying', 0xFFABA5A1),
      ColorVariant('钛柔金', 'builtin_samsung_s25u_tirou', 0xFFABA5A1),
      ColorVariant('钛翡绿', 'builtin_samsung_s25u_tifei', 0xFFABA5A1),
      ColorVariant('钛辉银', 'builtin_samsung_s25u_tihuibyin', 0xFFAEAEB0),
      ColorVariant('钛雾灰', 'builtin_samsung_s25u_tiwu', 0xFFABA5A1),
    ],
    // ── 三星 Galaxy S24 Ultra ──
    'builtin_samsung_s24u_timu': [
      ColorVariant('钛暮紫', 'builtin_samsung_s24u_timu', 0xFF7E7772),
      ColorVariant('钛岭绿', 'builtin_samsung_s24u_tiling', 0xFF686765),
      ColorVariant('钛川蓝', 'builtin_samsung_s24u_tichuan', 0xFF686765),
      ColorVariant('钛灰', 'builtin_samsung_s24u_tihui', 0xFF7D7671),
      ColorVariant('钛羽黄', 'builtin_samsung_s24u_tiyu', 0xFF898166),
      ColorVariant('钛霞橙', 'builtin_samsung_s24u_tixia', 0xFF89827C),
      ColorVariant('钛黑', 'builtin_samsung_s24u_tihei', 0xFF676563),
    ],
    // ── 荣耀 Magic9 Pro Max ──
    'builtin_honor_magic9pm_yinyan': [
      ColorVariant('银盐', 'builtin_honor_magic9pm_yinyan', 0xFFA8AAAA),
      ColorVariant('影黑', 'builtin_honor_magic9pm_yinghei', 0xFF57595B),
      ColorVariant('苔青', 'builtin_honor_magic9pm_taiqing', 0xFFAFB983),
    ],
    // ── 荣耀 Magic9 超能版 ──
    'builtin_honor_magic9x_kaichang': [
      ColorVariant('开场白', 'builtin_honor_magic9x_kaichang', 0xFF999B9E),
      ColorVariant('幕布黑', 'builtin_honor_magic9x_mubu', 0xFF595B62),
      ColorVariant('橄榄青', 'builtin_honor_magic9x_ganlan', 0xFF8F9D9E),
      ColorVariant('爆米黄', 'builtin_honor_magic9x_baomi', 0xFFA89255),
    ],
    // ── 荣耀 Magic9 ──
    'builtin_honor_magic9_kaichang': [
      ColorVariant('开场白', 'builtin_honor_magic9_kaichang', 0xFF9A9B9E),
      ColorVariant('幕布黑', 'builtin_honor_magic9_mubu', 0xFF595B63),
      ColorVariant('橄榄青', 'builtin_honor_magic9_ganlan', 0xFF8BA09E),
      ColorVariant('爆米黄', 'builtin_honor_magic9_baomi', 0xFFAE8E52),
    ],
    // ── 荣耀 Magic8 Pro ──
    'builtin_honor_magic8p_xuebai': [
      ColorVariant('雪域白', 'builtin_honor_magic8p_xuebai', 0xFF8D8D8D),
      ColorVariant('天青色', 'builtin_honor_magic8p_tianqing', 0xFF8C9496),
      ColorVariant('旭日金砂', 'builtin_honor_magic8p_xuri', 0xFF928D85),
      ColorVariant('绒黑色', 'builtin_honor_magic8p_ronghei', 0xFF87898B),
    ],
    // ── 荣耀 Magic8 ──
    'builtin_honor_magic8_xuebai': [
      ColorVariant('雪域白', 'builtin_honor_magic8_xuebai', 0xFF8E8E8E),
      ColorVariant('天青釉', 'builtin_honor_magic8_tianqing', 0xFF646665),
      ColorVariant('旭日金', 'builtin_honor_magic8_xuri', 0xFF89827A),
      ColorVariant('绒黑色', 'builtin_honor_magic8_ronghei', 0xFF747475),
    ],
};

/// 模板库展示图（正反图）: templateId → assets 路径
const Map<String, String> kTemplateDisplayFile = {
  'builtin_honor_magic9pm_yinyan': 'assets/templates/honor_magic9pm_yinyan_display.png',
  'builtin_honor_magic9pm_yinghei': 'assets/templates/honor_magic9pm_yinghei_display.png',
  'builtin_honor_magic9pm_taiqing': 'assets/templates/honor_magic9pm_taiqing_display.png',
  'builtin_honor_magic9x_kaichang': 'assets/templates/honor_magic9x_kaichang_display.png',
  'builtin_honor_magic9x_mubu': 'assets/templates/honor_magic9x_mubu_display.png',
  'builtin_honor_magic9x_ganlan': 'assets/templates/honor_magic9x_ganlan_display.png',
  'builtin_honor_magic9x_baomi': 'assets/templates/honor_magic9x_baomi_display.png',
  'builtin_honor_magic9_kaichang': 'assets/templates/honor_magic9_kaichang_display.png',
  'builtin_honor_magic9_mubu': 'assets/templates/honor_magic9_mubu_display.png',
  'builtin_honor_magic9_ganlan': 'assets/templates/honor_magic9_ganlan_display.png',
  'builtin_honor_magic9_baomi': 'assets/templates/honor_magic9_baomi_display.png',
  'builtin_honor_magic8p_xuebai': 'assets/templates/honor_magic8p_xuebai_display.png',
  'builtin_honor_magic8p_tianqing': 'assets/templates/honor_magic8p_tianqing_display.png',
  'builtin_honor_magic8p_xuri': 'assets/templates/honor_magic8p_xuri_display.png',
  'builtin_honor_magic8p_ronghei': 'assets/templates/honor_magic8p_ronghei_display.png',
  'builtin_honor_magic8_xuebai': 'assets/templates/honor_magic8_xuebai_display.png',
  'builtin_honor_magic8_tianqing': 'assets/templates/honor_magic8_tianqing_display.png',
  'builtin_honor_magic8_xuri': 'assets/templates/honor_magic8_xuri_display.png',
  'builtin_honor_magic8_ronghei': 'assets/templates/honor_magic8_ronghei_display.png',
  'builtin_samsung_s26u_xingshuang': 'assets/templates/samsung_s26u_xingshuang_display.png',
  'builtin_samsung_s26u_xingmu': 'assets/templates/samsung_s26u_xingmu_display.png',
  'builtin_samsung_s26u_xingyao': 'assets/templates/samsung_s26u_xingyao_display.png',
  'builtin_samsung_s26u_xingyue': 'assets/templates/samsung_s26u_xingyue_display.png',
  'builtin_samsung_s26u_xingcheng': 'assets/templates/samsung_s26u_xingcheng_display.png',
  'builtin_samsung_s26u_xinggui': 'assets/templates/samsung_s26u_xinggui_display.png',
  'builtin_samsung_s25u_tiyin': 'assets/templates/samsung_s25u_tiyin_display.png',
  'builtin_samsung_s25u_timo': 'assets/templates/samsung_s25u_timo_display.png',
  'builtin_samsung_s25u_tiying': 'assets/templates/samsung_s25u_tiying_display.png',
  'builtin_samsung_s25u_tirou': 'assets/templates/samsung_s25u_tirou_display.png',
  'builtin_samsung_s25u_tifei': 'assets/templates/samsung_s25u_tifei_display.png',
  'builtin_samsung_s25u_tihuibyin': 'assets/templates/samsung_s25u_tihuibyin_display.png',
  'builtin_samsung_s25u_tiwu': 'assets/templates/samsung_s25u_tiwu_display.png',
  'builtin_samsung_s24u_timu': 'assets/templates/samsung_s24u_timu_display.png',
  'builtin_samsung_s24u_tiling': 'assets/templates/samsung_s24u_tiling_display.png',
  'builtin_samsung_s24u_tichuan': 'assets/templates/samsung_s24u_tichuan_display.png',
  'builtin_samsung_s24u_tihui': 'assets/templates/samsung_s24u_tihui_display.png',
  'builtin_samsung_s24u_tiyu': 'assets/templates/samsung_s24u_tiyu_display.png',
  'builtin_samsung_s24u_tixia': 'assets/templates/samsung_s24u_tixia_display.png',
  'builtin_samsung_s24u_tihei': 'assets/templates/samsung_s24u_tihei_display.png',
  'builtin_realme_gt8pro_white': 'assets/templates/realme_gt8pro_white_display.png',
  'builtin_realme_gt8pro_blue': 'assets/templates/realme_gt8pro_blue_display.png',
  'builtin_realme_gt8pro_green': 'assets/templates/realme_gt8pro_green_display.png',
  'builtin_realme_gt8pro_amg': 'assets/templates/realme_gt8pro_amg_display.png',
  'builtin_realme_gt8_white': 'assets/templates/realme_gt8_white_display.png',
  'builtin_realme_gt8_green': 'assets/templates/realme_gt8_green_display.png',
  'builtin_realme_gt8_navy': 'assets/templates/realme_gt8_navy_display.png',
  'builtin_oneplus16_mingri': 'assets/templates/oneplus16_mingri_display.png',
  'builtin_oneplus16_huoxing': 'assets/templates/oneplus16_huoxing_display.png',
  'builtin_oneplus16_heian': 'assets/templates/oneplus16_heian_display.png',
  'builtin_oneplus15t_zhiyu': 'assets/templates/oneplus15t_zhiyu_display.png',
  'builtin_oneplus15t_songchi': 'assets/templates/oneplus15t_songchi_display.png',
  'builtin_oneplus15t_chuncui': 'assets/templates/oneplus15t_chuncui_display.png',
  'builtin_oneplus15_yuansha': 'assets/templates/oneplus15_yuansha_display.png',
  'builtin_oneplus15_juedui': 'assets/templates/oneplus15_juedui_display.png',
  'builtin_oneplus15_wuguang': 'assets/templates/oneplus15_wuguang_display.png',
  'builtin_oneplus13t_chenwu': 'assets/templates/oneplus13t_chenwu_display.png',
  'builtin_oneplus13t_yunmo': 'assets/templates/oneplus13t_yunmo_display.png',
  'builtin_oneplus13t_pengran': 'assets/templates/oneplus13t_pengran_display.png',
  'builtin_oneplus13_bailu': 'assets/templates/oneplus13_bailu_display.png',
  'builtin_oneplus13_landiao': 'assets/templates/oneplus13_landiao_display.png',
  'builtin_oneplus13_heiyao': 'assets/templates/oneplus13_heiyao_display.png',
  'builtin_iqoo16_chuanqi': 'assets/templates/iqoo16_chuanqi_display.png',
  'builtin_iqoo16_saidao': 'assets/templates/iqoo16_saidao_display.png',
  'builtin_iqoo16_zhuguang': 'assets/templates/iqoo16_zhuguang_display.png',
  'builtin_iqoo15_chuanqi': 'assets/templates/iqoo15_chuanqi_display.png',
  'builtin_iqoo15_lingyun': 'assets/templates/iqoo15_lingyun_display.png',
  'builtin_iqoo15_kuangye': 'assets/templates/iqoo15_kuangye_display.png',
  'builtin_iqoo15_wangzhe': 'assets/templates/iqoo15_wangzhe_display.png',
  'builtin_iqoo15_saidao': 'assets/templates/iqoo15_saidao_display.png',
  'builtin_iqoo15ultra_silver2049': 'assets/templates/iqoo15ultra_silver2049_display.png',
  'builtin_iqoo15ultra_black2077': 'assets/templates/iqoo15ultra_black2077_display.png',
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
