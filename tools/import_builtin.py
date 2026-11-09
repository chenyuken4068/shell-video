# -*- coding: utf-8 -*-
"""把用户导出的 .shtpl 模板「合入 App」，变成永久内置模板

用法（模板文件是 .zip，早期导出的 .shtpl 同样能读）：
  python tools/import_builtin.py 模板.zip --name "小明的壳"
  python tools/import_builtin.py 模板.zip --id xiaomi14 --transparent
  python tools/import_builtin.py --list

做的事：
  1) 校验包（zip 里只有 template.json + 一张图；尺寸/坐标合法）
  2) 图片写入 assets/templates/<slug>.png
  3) 更新 assets/templates/index.json（按 id 幂等，重复跑不会重复加）
  4) 输出 build/builtin_check_<slug>.png（壳图 + 标定框），肉眼看一眼框对不对
之后：重新打包 APK，所有用户（含已安装的，升级后）就都有这个内置模板了

注：默认目录可以用 --assets-dir / --check-dir 改（自测时用临时目录，避免动到真 assets）
"""
import argparse
import io
import json
import os
import re
import sys
import zipfile

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("需要 Pillow：pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_IMAGE_BYTES = 12 * 1024 * 1024
MAX_SIDE = 5000


def slugify(s):
    """id / 文件名用 ASCII（asset 名、目录名更稳）；纯中文名退化成 tpl_<短hash>。
    显示名不受影响（走 --name / 包里的 name）"""
    s = re.sub(r"[^0-9A-Za-z_-]+", "_", s.strip()).strip("_")
    if not s:
        import hashlib
        s = "tpl_" + hashlib.md5(s.encode("utf-8") if s else os.urandom(4)).hexdigest()[:6]
    if not re.search(r"[0-9A-Za-z]", s):
        import hashlib
        s = "tpl_" + hashlib.md5(s.encode("utf-8")).hexdigest()[:6]
    return s[:40] or "template"


def load_index(path):
    if not os.path.exists(path):
        return {"format": 1, "templates": []}
    with io.open(path, encoding="utf-8") as f:
        j = json.load(f)
    if isinstance(j, list):
        return {"format": 1, "templates": j}
    j.setdefault("templates", [])
    return j


def read_pack(pack_path):
    if not os.path.exists(pack_path):
        raise SystemExit("找不到文件：%s" % pack_path)
    size = os.path.getsize(pack_path)
    if size > 20 * 1024 * 1024:
        raise SystemExit("包太大（%.1fMB，上限 20MB）" % (size / 1048576.0))
    with zipfile.ZipFile(pack_path) as z:
        names = [n for n in z.namelist() if not n.endswith("/")]
        meta_name = "template.json" if "template.json" in names else None
        if meta_name is None:
            raise SystemExit("包里缺少 template.json")
        others = [n for n in names if n != "template.json"]
        if len(others) != 1:
            raise SystemExit("包里应当只有一张图，实际 %d 个" % len(others))
        meta = json.loads(z.read("template.json").decode("utf-8"))
        img_bytes = z.read(others[0])
    if meta.get("format") != 1:
        raise SystemExit("模板格式版本不支持：%r" % meta.get("format"))
    if len(img_bytes) > MAX_IMAGE_BYTES:
        raise SystemExit("图片太大（上限 12MB）")
    return meta, img_bytes


def check_values(meta, w, h):
    def num(k, d=0):
        v = meta.get(k, d)
        return int(v) if isinstance(v, (int, float)) else d

    x, y = num("screenX"), num("screenY")
    sw, sh = num("screenW"), num("screenH")
    r = num("cornerR")
    if sw <= 0 or sh <= 0:
        raise SystemExit("屏幕框参数无效：%dx%d" % (sw, sh))
    x = max(0, min(x, w - 1))
    y = max(0, min(y, h - 1))
    sw = max(1, min(sw, w - x))
    sh = max(1, min(sh, h - y))
    r = max(0, min(r, min(sw, sh) // 2))
    return x, y, sw, sh, r


def draw_check(img_path, out_path, x, y, sw, sh, r):
    im = Image.open(img_path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    im = bg.convert("RGB")
    d = ImageDraw.Draw(im)
    # 屏幕框（蓝）+ 外扩 6% 屏宽后的壳框（橙）
    d.rounded_rectangle([x, y, x + sw - 1, y + sh - 1], radius=r, outline=(10, 132, 255), width=6)
    pad = round(sw * 0.06)
    d.rectangle([x - pad, y - pad, x + sw - 1 + pad, y + sh - 1 + pad], outline=(255, 149, 0), width=4)
    im.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack", nargs="?", help=".shtpl 文件")
    ap.add_argument("--name", help="模板显示名（默认用包里的名字）")
    ap.add_argument("--id", help="内置 id / 文件名（默认按名字生成）")
    ap.add_argument("--transparent", action="store_true", help="标记为透明模板")
    ap.add_argument("--list", action="store_true", help="只看现有内置清单")
    ap.add_argument("--assets-dir", default=os.path.join(ROOT, "assets", "templates"))
    ap.add_argument("--check-dir", default=os.path.join(ROOT, "build"))
    args = ap.parse_args()

    index_path = os.path.join(args.assets_dir, "index.json")
    index = load_index(index_path)

    if args.list:
        print("内置模板清单（%s）：" % index_path)
        for t in index["templates"]:
            print("  - id=%-18s name=%-14s file=%-18s 屏幕框=%s,%s %sx%s r=%s%s"
                  % (t.get("id"), t.get("name"), t.get("file"), t.get("x"), t.get("y"),
                     t.get("w"), t.get("h"), t.get("r"),
                     " 透明" if t.get("transparent") else ""))
        return

    if not args.pack:
        ap.error("需要 .shtpl 文件（或用 --list 看清单）")

    meta, img_bytes = read_pack(args.pack)
    name = args.name or str(meta.get("name") or "导入模板")
    slug = slugify(args.id or name)
    os.makedirs(args.assets_dir, exist_ok=True)
    img_name = slug + ".png"
    img_path = os.path.join(args.assets_dir, img_name)

    tmp_img = os.path.join(args.check_dir, "_tmp_%s.png" % slug)
    os.makedirs(args.check_dir, exist_ok=True)
    with open(tmp_img, "wb") as f:
        f.write(img_bytes)
    try:
        with Image.open(tmp_img) as im:
            w, h = im.size
    except Exception as e:
        raise SystemExit("图片无法解码：%s" % e)
    if w > MAX_SIDE or h > MAX_SIDE:
        raise SystemExit("图片尺寸过大：%dx%d（上限 %d）" % (w, h, MAX_SIDE))

    x, y, sw, sh, r = check_values(meta, w, h)
    transparent = bool(args.transparent or meta.get("isTransparent"))

    with open(img_path, "wb") as f:
        f.write(img_bytes)

    entry = {
        "id": slug,
        "name": name,
        "file": img_name,
        "x": x, "y": y, "w": sw, "h": sh, "r": r,
        "transparent": transparent,
    }
    replaced = False
    for i, t in enumerate(index["templates"]):
        if t.get("id") == slug:
            index["templates"][i] = entry
            replaced = True
            break
    if not replaced:
        index["templates"].append(entry)
    index["format"] = 1
    with io.open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    check_path = os.path.join(args.check_dir, "builtin_check_%s.png" % slug)
    draw_check(img_path, check_path, x, y, sw, sh, r)
    os.remove(tmp_img)

    print("[OK] %s内置模板：%s (id=%s)" % ("更新" if replaced else "新增", name, slug))
    print("     图片 : %s  (%dx%d)" % (img_path, w, h))
    print("     屏幕框: (%d,%d) %dx%d  r=%d%s" % (x, y, sw, sh, r, "  透明模板" if transparent else ""))
    print("     清单 : %s" % index_path)
    print("     核对图: %s  ← 打开看一眼蓝框（屏幕）和橙框（外扩 6%% 的壳框）对不对" % check_path)
    print("下一步：重新打包 APK（flutter build apk ...），所有用户升级后即可见")


if __name__ == "__main__":
    main()
