#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""calib_detect.py —— App 内置模板「屏幕区域」标定工具（多线取样版）

用途：扫描 assets/templates 里的壳图，按透明通道算出屏幕孔坐标，
      并把同机型多颜色统一成同一组数值，写回 index.json。

算法（每边 10 条线取样取中位数，替代旧版全像素 min/max）：
  1. 从四条边 flood-fill 透明区 = 壳外；
  2. 剩下的透明像素 = 屏幕孔（被壳包围）；
  3. 四条边各取 10 条检测线（以屏幕质心为基准，间隔 20px）：
       左/右 → 10 行各自找最左/最右像素
       上/下 → 10 列各自找最上/最下像素（上边跳过 |x-中心| < 40 的列，避摄像头）
     各取中位数 = 该边界；抗个别噪点、抗挖孔
  4. 圆角 r：左右两侧「屏幕行首次到达 x0」的行数取中位数；
  5. 同机型（name 中 · 前面部分相同）多颜色 → 每个字段取中位数统一。

用法：
  python tools/calib_detect.py                 # 只报告差异，不写文件
  python tools/calib_detect.py --apply         # 写回 index.json
  python tools/calib_detect.py --only oppo vivo --apply   # 只处理指定前缀
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sys
from collections import deque
from statistics import median

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPL = os.path.join(ROOT, "assets", "templates")
INDEX = os.path.join(TPL, "index.json")

ALPHA_TH = 200
LINES = 10
SPACING = 20
TOPCAM_SKIP = 40


import numpy as np

try:
    from scipy import ndimage as _ndi
    _HAS_SCIPY = True
except Exception:
    _ndi = None
    _HAS_SCIPY = False


def _screen_arrays(path):
    """返回 (screen_mask, rows, cols, cx, cy, n)，numpy 矢量化，毫秒级。"""
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im)
    h, w = arr.shape[:2]
    transparent = arr[:, :, 3] < ALPHA_TH

    if _HAS_SCIPY:
        lab, _n = _ndi.label(transparent)
        # 与四条边相接的连通块 = 壳外
        edge_labels = set()
        edge_labels.update(np.unique(lab[0, :]).tolist())
        edge_labels.update(np.unique(lab[-1, :]).tolist())
        edge_labels.update(np.unique(lab[:, 0]).tolist())
        edge_labels.update(np.unique(lab[:, -1]).tolist())
        edge_labels.discard(0)
        outside = np.isin(lab, list(edge_labels)) if edge_labels else np.zeros_like(transparent)
    else:
        # 兜底：scipy 缺失时用 BFS（慢）
        outside = np.zeros((h, w), dtype=bool)
        dq = deque()
        for x in range(w):
            for y in (0, h - 1):
                if transparent[y, x] and not outside[y, x]:
                    outside[y, x] = True
                    dq.append((x, y))
        for y in range(h):
            for x in (0, w - 1):
                if transparent[y, x] and not outside[y, x]:
                    outside[y, x] = True
                    dq.append((x, y))
        while dq:
            x, y = dq.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and transparent[ny, nx] and not outside[ny, nx]:
                    outside[ny, nx] = True
                    dq.append((nx, ny))

    screen = transparent & ~outside
    n = int(screen.sum())
    if n == 0:
        return None

    ys, xs = np.nonzero(screen)
    cx, cy = float(xs.mean()), float(ys.mean())

    # 每行屏幕的最左/最右
    rows = {}
    row_any = screen.any(axis=1)
    for y in np.nonzero(row_any)[0]:
        idx = np.nonzero(screen[y])[0]
        rows[int(y)] = (int(idx[0]), int(idx[-1]))
    # 每列屏幕的最上/最下
    cols = {}
    col_any = screen.any(axis=0)
    for x in np.nonzero(col_any)[0]:
        idx = np.nonzero(screen[:, x])[0]
        cols[int(x)] = (int(idx[0]), int(idx[-1]))

    return dict(rows=rows, cols=cols, n=n, cx=cx, cy=cy)


def detect(path):
    sm = _screen_arrays(path)
    if sm is None:
        return None
    cx, cy = sm["cx"], sm["cy"]
    rows, cols = sm["rows"], sm["cols"]

    lefts, rights, tops, bottoms = [], [], [], []
    for k in range(LINES):
        off = (k - (LINES - 1) / 2.0) * SPACING
        y = int(round(cy + off))
        if y in rows:
            lefts.append(rows[y][0])
            rights.append(rows[y][1])
        x = int(round(cx + off))
        if x in cols:
            if abs(x - cx) >= TOPCAM_SKIP:
                tops.append(cols[x][0])
            bottoms.append(cols[x][1])

    def med(vals, fallback):
        return int(round(median(vals))) if vals else fallback

    x0 = med(lefts, min(r[0] for r in rows.values()))
    x1 = med(rights, max(r[1] for r in rows.values()))
    y0 = med(tops, min(c[0] for c in cols.values()))
    y1 = med(bottoms, max(c[1] for c in cols.values()))
    sw, sh = x1 - x0 + 1, y1 - y0 + 1

    rr = []
    for y in sorted(rows):
        if rows[y][0] <= x0 + 1:
            rr.append(y - y0)
            break
    for y in sorted(rows, reverse=True):
        if rows[y][0] <= x0 + 1:
            rr.append(y1 - y)
            break
    r = int(round(median(rr))) if rr else int(sw * 0.07)
    r = max(8, min(r, int(sw * 0.2)))
    return dict(x=x0, y=y0, w=sw, h=sh, r=r)


def model_key(name: str) -> str:
    """「Find X10 Pro Max · 暖橙」→「Find X10 Pro Max」"""
    return name.split("·")[0].strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="写回 index.json")
    ap.add_argument("--only", nargs="*", default=None,
                    help="只处理 id 以此开头的模板，如 oppo vivo")
    args = ap.parse_args()

    j = json.load(io.open(INDEX, encoding="utf-8"))
    tpls = j["templates"]

    sel = [t for t in tpls if args.only is None
           or any(t["id"].startswith(p) for p in args.only)]
    print("=" * 78)
    print("多线取样标定（每边 %d 条 / 间隔 %dpx / 中位数 / 上边避摄像头 %dpx）"
          % (LINES, SPACING, TOPCAM_SKIP))
    print("待处理模板: %d 个" % len(sel))
    print("=" * 78)

    # 1) 逐个测
    groups = {}
    failed = []
    for t in sel:
        p = os.path.join(TPL, t["file"])
        if not os.path.exists(p):
            failed.append((t["id"], "文件不存在"))
            continue
        d = detect(p)
        if d is None:
            failed.append((t["id"], "检测失败"))
            continue
        groups.setdefault(model_key(t["name"]), []).append((t, d))

    # 2) 同机型统一（各字段中位数）
    changes = 0
    for model, items in sorted(groups.items()):
        unify = {}
        for f in ("x", "y", "w", "h", "r"):
            unify[f] = int(round(median([d[f] for _, d in items])))
        print()
        print("■ %s（%d 个颜色）→ 统一 x=%d y=%d w=%d h=%d r=%d"
              % (model, len(items), unify["x"], unify["y"], unify["w"], unify["h"], unify["r"]))
        for t, d in items:
            diff = tuple(d[f] - t[f] for f in ("x", "y", "w", "h", "r"))
            udiff = tuple(unify[f] - t[f] for f in ("x", "y", "w", "h", "r"))
            flag = "" if udiff == (0, 0, 0, 0, 0) else "  ← 改"
            print("   %-34s 实测 x=%-4d y=%-4d w=%-4d h=%-4d r=%-3d  差%+d%+d%+d%+d%+d%s"
                  % (t["id"], d["x"], d["y"], d["w"], d["h"], d["r"],
                     diff[0], diff[1], diff[2], diff[3], diff[4], flag))
            if udiff != (0, 0, 0, 0, 0):
                changes += 1
                if args.apply:
                    t["x"], t["y"], t["w"], t["h"], t["r"] = (
                        unify["x"], unify["y"], unify["w"], unify["h"], unify["r"])

    if failed:
        print()
        print("!! 失败 %d 个：" % len(failed))
        for tid, why in failed:
            print("   %-34s %s" % (tid, why))

    print()
    print("=" * 78)
    print("需要修改: %d 个模板" % changes)
    if args.apply:
        io.open(INDEX, "w", encoding="utf-8", newline="\n").write(
            json.dumps(j, ensure_ascii=False, indent=2))
        print("已写回: %s" % INDEX)
    else:
        print("（仅报告，未写入；加 --apply 生效）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
