#version 460 core
#include <flutter/runtime_effect.glsl>

// 液态玻璃（通透镜面 + 弧面折射 + 外圈高光环）
// 坐标：FlutterFragCoord 是"过滤器区域"的局部坐标（物理像素）；
//       背板纹理是整块屏幕，所以背景采样要加回 uOrigin。
uniform float uRadius;        // 0    底栏圆角
uniform vec4 uPill;           // 1..4 胶囊 left, top, w, h（局部坐标）
uniform float uPillR;         // 5    胶囊圆角
uniform float uBevel;         // 6    弧面宽度
uniform float uStrength;      // 7    扭曲强度
uniform float uFrost;         // 8    0=通透 1=毛玻璃
uniform float uTint;          // 9    染色
uniform float uDark;          // 10   1=深色
uniform float uRing;          // 11   外圈高光环宽
uniform float uRingStrength;  // 12   外圈高光强度
uniform vec2 uSize;           // 13,14 底栏尺寸（局部坐标范围）
uniform vec2 uOrigin;         // 15,16 底栏左上角在屏幕上的位置
uniform vec2 uViewSize;       // 17,18 屏幕（背板）尺寸
uniform sampler2D uTex;       // 背板

out vec4 fragColor;

float sdRB(vec2 p, vec2 c, vec2 h, float r) {
  vec2 q = abs(p - c) - (h - r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 gradRB(vec2 p, vec2 c, vec2 h, float r) {
  float e = 0.9;
  return vec2(sdRB(p + vec2(e, 0.0), c, h, r) - sdRB(p - vec2(e, 0.0), c, h, r),
              sdRB(p + vec2(0.0, e), c, h, r) - sdRB(p - vec2(0.0, e), c, h, r));
}

vec4 texAt(vec2 uv) {
  return texture(uTex, clamp(uv, vec2(0.002), vec2(0.998)));
}

vec4 sampleGlass(vec2 uv) {
  if (uFrost < 0.02) return texAt(uv);
  float rad = (0.6 + uFrost * 18.0) / max(uViewSize.y, 1.0);
  vec4 sum = vec4(0.0);
  float wsum = 0.0;
  for (int i = -2; i <= 2; i++) {
    for (int j = -2; j <= 2; j++) {
      float w = exp(-float(i * i + j * j) / 4.5);
      sum += texAt(uv + vec2(float(i), float(j)) * rad * 0.55) * w;
      wsum += w;
    }
  }
  return sum / wsum;
}

vec4 glassAt(vec2 p, vec2 uv, vec2 c, vec2 h, float r, float d) {
  float inside = max(-d, 0.0);
  float u = 1.0 - clamp(inside / uBevel, 0.0, 1.0);
  float ramp = (1.0 - u) * (1.0 - u);   // 扭曲只在弧面带内，向内侧平滑衰减到 0
  vec2 n = normalize(gradRB(p, c, h, r) + vec2(1e-5));
  float k = ramp * uStrength * uBevel * 0.85;
  vec2 off = n * k / uViewSize;         // uv 是屏幕空间，位移按屏幕尺寸换算
  vec4 col = sampleGlass(uv + off);

  vec3 tintCol = uDark > 0.5 ? vec3(0.16, 0.17, 0.20) : vec3(1.0);
  col = vec4(mix(col.rgb, tintCol, uTint * (0.45 + 0.55 * (1.0 - ramp))), 1.0);

  vec2 L = normalize(vec2(-0.55, 0.83));
  float ndl = max(dot(n, L), 0.0);
  // 弧面定向高光
  col.rgb += vec3(pow(ndl, 18.0) * exp(-inside / 1.6) * (uDark > 0.5 ? 1.35 : 0.90));
  // 外圈一圈高光
  float ring = smoothstep(uRing, 0.0, inside);
  col.rgb += vec3(uRingStrength * (0.45 + 0.75 * ndl) * ring * (uDark > 0.5 ? 1.0 : 0.85));
  // 环内侧柔光
  col.rgb += vec3(0.10) * exp(-inside / max(uRing * 3.0, 1.0));
  // 极细轮廓
  col.rgb += vec3(uDark > 0.5 ? 0.10 : 0.06) * smoothstep(1.1, 0.0, abs(d));
  return col;
}

void main() {
  vec2 p = FlutterFragCoord().xy;                  // 底栏局部坐标
  vec2 uv = (p + uOrigin) / uViewSize;             // 背景（整屏）采样坐标
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 col = texAt(uv);
  vec2 bc = uSize * 0.5;
  float db = sdRB(p, bc, uSize * 0.5, uRadius);
  float dp = sdRB(p, uPill.xy + uPill.zw, uPill.zw * 0.5, uPillR);

  if (db < 0.0) col = glassAt(p, uv, bc, uSize * 0.5, uRadius, db);
  if (dp < 0.0) col = glassAt(p, uv, uPill.xy + uPill.zw, uPill.zw * 0.5, uPillR, dp);

  fragColor = col;
}
