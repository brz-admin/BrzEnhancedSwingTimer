#!/usr/bin/env python3
"""Generates the textures of the addon (Textures/*.tga).

Everything is white with an alpha channel (or a grey ramp) so the addon can tint it with
SetVertexColor. Format: uncompressed 32 bit TGA, bottom-left origin, power of two sizes, which
is what the 1.12 client loads.

Usage: python3 tools/make_media.py   (from the addon folder, needs Pillow)
"""
import colorsys
import math
import os
import struct

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Textures")
SS = 8  # supersampling for the drawn shapes


def write_tga(name, img):
    img = img.convert("RGBA")
    w, h = img.size
    # Bottom-left origin (descriptor 0x08) is the layout every TGA reader agrees on
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    px = img.load()
    data = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            data += bytes((b, g, r, a))
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + bytes(data))
    print("wrote", name, w, h)


def ramp(w, h, fn):
    """fn(x, y) -> grey 0..1, alpha is always 1."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            v = max(0.0, min(1.0, fn(x / max(w - 1, 1), y / max(h - 1, 1))))
            c = int(round(v * 255))
            px[x, y] = (c, c, c, 255)
    return img


def drawn(size, painter):
    big = Image.new("RGBA", (size * SS, size * SS), (255, 255, 255, 0))
    painter(ImageDraw.Draw(big), size * SS)
    return big.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)

    write_tga("white.tga", Image.new("RGBA", (8, 8), (255, 255, 255, 255)))

    # Bar textures: grey ramps, the bar colour multiplies them
    write_tga("bar_gradient.tga", ramp(16, 64, lambda x, y: 1.0 - 0.38 * y))
    write_tga("bar_glossy.tga", ramp(16, 64, lambda x, y: (1.0 - 0.15 * y) if y < 0.5 else (0.66 - 0.2 * (y - 0.5))))
    write_tga("bar_smooth.tga", ramp(256, 8, lambda x, y: 0.62 + 0.38 * x))

    def stripes(x, y):
        # 45 degree stripes, 16 px period on a 128x16 canvas
        u = (x * 128 + y * 16) / 16.0
        return 1.0 if (u - math.floor(u)) < 0.5 else 0.8

    write_tga("bar_stripes.tga", ramp(128, 16, stripes))

    # Spark: soft vertical glow, bright in the middle
    spark = Image.new("RGBA", (16, 64))
    px = spark.load()
    for y in range(64):
        for x in range(16):
            dx = (x - 7.5) / 7.5
            dy = (y - 31.5) / 31.5
            a = math.exp(-(dx * dx) * 5.0) * math.exp(-(dy * dy) * 2.2)
            px[x, y] = (255, 255, 255, int(round(max(0.0, min(1.0, a)) * 255)))
    write_tga("spark.tga", spark)

    # Interface glyphs
    def check(d, s):
        w = int(s * 0.13)
        d.line([(s * 0.2, s * 0.53), (s * 0.43, s * 0.74), (s * 0.8, s * 0.27)], fill=(255, 255, 255, 255), width=w, joint="curve")

    def arrow(d, s):
        w = int(s * 0.12)
        d.line([(s * 0.25, s * 0.38), (s * 0.5, s * 0.63), (s * 0.75, s * 0.38)], fill=(255, 255, 255, 255), width=w, joint="curve")

    def close(d, s):
        w = int(s * 0.11)
        d.line([(s * 0.27, s * 0.27), (s * 0.73, s * 0.73)], fill=(255, 255, 255, 255), width=w)
        d.line([(s * 0.73, s * 0.27), (s * 0.27, s * 0.73)], fill=(255, 255, 255, 255), width=w)

    # Color picker: alpha ramps that get tinted (white over a hue = saturation, black = value),
    # the hue rainbow and the ring of the picked point
    grad_h = Image.new("RGBA", (256, 8))
    px = grad_h.load()
    for x in range(256):
        for y in range(8):
            px[x, y] = (255, 255, 255, 255 - x)
    write_tga("grad_h.tga", grad_h)

    grad_v = Image.new("RGBA", (8, 256))
    px = grad_v.load()
    for y in range(256):
        for x in range(8):
            px[x, y] = (255, 255, 255, y)
    write_tga("grad_v.tga", grad_v)

    hue = Image.new("RGBA", (256, 8))
    px = hue.load()
    for x in range(256):
        r, g, b = colorsys.hsv_to_rgb(x / 255.0, 1.0, 1.0)
        for y in range(8):
            px[x, y] = (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), 255)
    write_tga("hue.tga", hue)

    def ring(d, s):
        d.ellipse([s * 0.12, s * 0.12, s * 0.88, s * 0.88], outline=(0, 0, 0, 255), width=int(s * 0.16))
        d.ellipse([s * 0.19, s * 0.19, s * 0.81, s * 0.81], outline=(255, 255, 255, 255), width=int(s * 0.1))

    write_tga("ring.tga", drawn(16, ring))

    write_tga("check.tga", drawn(16, check))
    write_tga("arrow.tga", drawn(16, arrow))
    write_tga("close.tga", drawn(16, close))


if __name__ == "__main__":
    main()
