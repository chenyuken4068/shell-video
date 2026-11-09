import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 玻璃参考块：一小块真实玻璃 + 彩色底，用来直观看出「通透 ←→ 实」的差别。
/// 渲染方式与底栏一致：磨砂模糊 + 白色染色（染色浓度 = 通透度）+ 左上高光边。
class GlassPreviewTile extends StatelessWidget {
  const GlassPreviewTile({
    super.key,
    required this.opacity,
    this.height = 60,
    this.radius = 16,
  });

  /// 白染色浓度（越小越透）：0.02 ~ 0.30
  final double opacity;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            // 彩色底：用来观察玻璃透出多少、模糊多少
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7B5CFF),
                      Color(0xFF3FA2FF),
                      Color(0xFF35D6A4),
                      Color(0xFFFFB347),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Stack(children: [
                for (final b in const [
                  [-10.0, 6.0, 46.0, Color(0xFFFF5C8A)],
                  [70.0, 20.0, 40.0, Color(0xFFFFE066)],
                  [150.0, -8.0, 54.0, Color(0xFF0A84FF)],
                ])
                  Positioned(
                    left: b[0] as double,
                    top: b[1] as double,
                    child: Container(
                      width: b[2] as double,
                      height: b[2] as double,
                      decoration: BoxDecoration(
                        color: (b[3] as Color).withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
            ),
            // 玻璃：磨砂 + 白色染色（浓度 = 通透度）
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: opacity),
                        Colors.white.withValues(alpha: opacity * 0.42),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 左上高光边 + 内侧辉光
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            const Center(
              child: Text(
                '玻璃参考',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1D22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
