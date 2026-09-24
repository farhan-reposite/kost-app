"""Regenerates the app icon assets (assets/icon/icon.png and
assets/icon/icon_foreground.png) used by flutter_launcher_icons.

Run with: python3 gen_icon.py
Requires: pip install pillow
"""
import math
from PIL import Image, ImageDraw

TEAL = (14, 110, 100, 255)   # #0E6E64 - refined teal, matches lib/core/theme.dart
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

SS = 4          # supersample factor for smooth edges
BASE = 1024
S = BASE * SS


def key_glyph(size, fg, bg=None, hole_is_transparent=False):
    """An RGBA image of a simple key mark, centered in a size x size canvas."""
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(img)

    bow_center = (size * 0.40, size * 0.40)
    bow_outer_r = size * 0.185
    bow_inner_r = size * 0.095
    shaft_w = size * 0.105

    d.ellipse(
        [bow_center[0] - bow_outer_r, bow_center[1] - bow_outer_r,
         bow_center[0] + bow_outer_r, bow_center[1] + bow_outer_r],
        fill=fg,
    )
    hole_fill = TRANSPARENT if hole_is_transparent else bg
    d.ellipse(
        [bow_center[0] - bow_inner_r, bow_center[1] - bow_inner_r,
         bow_center[0] + bow_inner_r, bow_center[1] + bow_inner_r],
        fill=hole_fill,
    )

    shaft_start = (bow_center[0] + bow_outer_r * 0.55, bow_center[1] + bow_outer_r * 0.55)
    shaft_end = (size * 0.76, size * 0.76)
    d.line([shaft_start, shaft_end], fill=fg, width=int(shaft_w))
    r = shaft_w / 2
    for c in (shaft_start, shaft_end):
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=fg)

    dx, dy = shaft_end[0] - shaft_start[0], shaft_end[1] - shaft_start[1]
    dist = math.hypot(dx, dy)
    ux, uy = dx / dist, dy / dist
    px, py = -uy, ux

    def tooth(t, length, width):
        base = (shaft_start[0] + ux * dist * t, shaft_start[1] + uy * dist * t)
        tip = (base[0] + px * length, base[1] + py * length)
        d.line([base, tip], fill=fg, width=int(width))
        rr = width / 2
        d.ellipse([base[0] - rr, base[1] - rr, base[0] + rr, base[1] + rr], fill=fg)
        d.ellipse([tip[0] - rr, tip[1] - rr, tip[0] + rr, tip[1] + rr], fill=fg)

    tooth(0.70, size * 0.095, size * 0.085)
    tooth(0.90, size * 0.135, size * 0.085)

    return img


# 1. Full icon: solid background + glyph, full bleed (the OS applies its own mask)
full = Image.new("RGBA", (S, S), TEAL)
glyph_full = key_glyph(int(S * 0.62), WHITE, bg=TEAL, hole_is_transparent=False)
off = (S - glyph_full.width) // 2
full.alpha_composite(glyph_full, (off, off))
full = full.resize((BASE, BASE), Image.LANCZOS)
full.convert("RGB").save("assets/icon/icon.png")

# 2. Adaptive-icon foreground: transparent background, glyph kept inside the safe zone
fg_canvas = Image.new("RGBA", (S, S), TRANSPARENT)
glyph_fg = key_glyph(int(S * 0.46), WHITE, hole_is_transparent=True)
off2 = (S - glyph_fg.width) // 2
fg_canvas.alpha_composite(glyph_fg, (off2, off2))
fg_canvas = fg_canvas.resize((BASE, BASE), Image.LANCZOS)
fg_canvas.save("assets/icon/icon_foreground.png")

print("Wrote assets/icon/icon.png and assets/icon/icon_foreground.png")
