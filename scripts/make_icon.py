#!/usr/bin/env python3
"""Optional design asset regeneration; requires Pillow. Build uses the bundled PNG."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
scale = 3
image = Image.new("RGB", (1024 * scale, 1024 * scale), "#080e0c")
draw = ImageDraw.Draw(image)
mint = "#7affbf"


def line(points, width=36):
    pts = [(int(x * scale), int(y * scale)) for x, y in points]
    draw.line(pts, fill=mint, width=width * scale, joint="curve")
    for x, y in [pts[0], pts[-1]]:
        r = width * scale / 2
        draw.ellipse((x-r, y-r, x+r, y+r), fill=mint)


for points in [[(310, 212), (212, 212), (212, 310)], [(714, 212), (812, 212), (812, 310)],
               [(212, 714), (212, 812), (310, 812)], [(812, 714), (812, 812), (714, 812)]]:
    line(points)
eye = []
for direction in [-1, 1]:
    for step in range(101):
        t = step / 100
        eye.append(((1-t)**2 * 264 + 2*(1-t)*t*512 + t*t*760,
                    (1-t)**2 * 512 + 2*(1-t)*t*(512 + direction*254) + t*t*512))
    line(eye[-101:])
draw.ellipse(tuple(int(x*scale) for x in (424, 424, 600, 600)), outline=mint, width=36*scale)
draw.ellipse(tuple(int(x*scale) for x in (486, 486, 538, 538)), fill=mint)
output = ROOT / "AIMat/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(output)
print(output)
