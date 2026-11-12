"""Builds Android launcher icons from one square source image.

Usage: python make_icons.py <source image> <project root>
Writes the source into assets/icon/, legacy square icons for every density,
and an adaptive icon (white background + padded foreground).
"""
import os
import sys

from PIL import Image

src_path, root = sys.argv[1], sys.argv[2]
res = os.path.join(root, "android", "app", "src", "main", "res")
src = Image.open(src_path).convert("RGB")

os.makedirs(os.path.join(root, "assets", "icon"), exist_ok=True)
src.save(os.path.join(root, "assets", "icon", "app_icon.png"))

densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, scale in densities.items():
    folder = os.path.join(res, f"mipmap-{name}")
    os.makedirs(folder, exist_ok=True)
    # Legacy icon: 48dp, the whole image.
    size = round(48 * scale)
    src.resize((size, size), Image.LANCZOS).save(
        os.path.join(folder, "ic_launcher.png")
    )
    # Adaptive foreground: 108dp canvas. The launcher only shows the middle
    # 66%, so the image is drawn at 90% to keep the whole mark inside it.
    canvas = round(108 * scale)
    inner = round(canvas * 0.90)
    fg = Image.new("RGB", (canvas, canvas), (255, 255, 255))
    offset = (canvas - inner) // 2
    fg.paste(src.resize((inner, inner), Image.LANCZOS), (offset, offset))
    fg.save(os.path.join(folder, "ic_launcher_foreground.png"))

adaptive = os.path.join(res, "mipmap-anydpi-v26")
os.makedirs(adaptive, exist_ok=True)
with open(os.path.join(adaptive, "ic_launcher.xml"), "w", newline="\n") as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
with open(
    os.path.join(res, "values", "ic_launcher_background.xml"), "w", newline="\n"
) as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        "</resources>\n"
    )
print("icons written")
