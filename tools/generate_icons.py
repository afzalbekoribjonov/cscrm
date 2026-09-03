"""CSCRM logotip va ikonkalarini generatsiya qiladi.

Ishga tushirish (loyiha ildizidan):
    python tools/generate_icons.py

Yaratiladigan fayllar:
    app/assets/icon/logo.png             1024x1024  to'liq ikonka
    app/assets/icon/logo_foreground.png  1024x1024  adaptive foreground
    app/web/favicon.png                    64x64
    app/web/icons/Icon-{192,512}.png
    app/web/icons/Icon-maskable-{192,512}.png
    admin/public/favicon.png               64x64
    admin/public/logo.svg                            vektor (websayt uchun)
    app/android/.../drawable-*/launch_image.png      native splash nishoni

Nishon g'oyasi: brend ko'k gradient ustida oq tomchi + porlash - tozalash
xizmati va "toza natija" ma'nosini beradi.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Brend palitrasi (lib/theme/app_colors.dart bilan bir xil bo'lishi shart).
BRAND_TOP = (11, 95, 255)      # #0B5FFF
BRAND_BOTTOM = (0, 194, 255)   # #00C2FF
WHITE = (255, 255, 255, 255)

S = 1024  # ishchi o'lcham (keyin kichraytiriladi)


def _vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    """Yuqoridan pastga tik gradient."""
    grad = Image.new("RGB", (1, size))
    px = grad.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = (
            round(top[0] + (bottom[0] - top[0]) * t),
            round(top[1] + (bottom[1] - top[1]) * t),
            round(top[2] + (bottom[2] - top[2]) * t),
        )
    return grad.resize((size, size), Image.BILINEAR)


def _droplet_mask(size: int, scale: float = 1.0, dy: float = 0.0) -> Image.Image:
    """Tomchi shakli uchun alfa niqob.

    Tomchi = pastdagi doira + tepadagi uchburchak uchi. Ikkalasi bitta
    niqobga chiziladi, shuning uchun ular silliq qo'shiladi.
    """
    ss = 4  # supersampling - chekkalari silliq chiqishi uchun
    m = Image.new("L", (size * ss, size * ss), 0)
    d = ImageDraw.Draw(m)

    cx = size * ss / 2
    # Tomchining umumiy balandligi va pastki doira radiusi.
    h = size * ss * 0.62 * scale
    r = h * 0.42
    cy = size * ss * (0.56 + dy) + h * 0.5 - r

    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    # Tepa uchi: doiraning yon nuqtalaridan yuqoriga cho'ziladi.
    tip_y = cy - h * 0.86
    # Doira bilan uchburchak tutashadigan joy - radiusdan biroz yuqorida
    # olinsa, birikma joyi ko'rinmaydi.
    join_y = cy - r * 0.30
    join_dx = r * 0.955
    d.polygon(
        [(cx, tip_y), (cx - join_dx, join_y), (cx + join_dx, join_y)],
        fill=255,
    )
    return m.resize((size, size), Image.LANCZOS)


def _sparkle(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill):
    """To'rt uchli porlash (yulduzcha)."""
    thin = r * 0.20
    draw.polygon(
        [(cx, cy - r), (cx + thin, cy - thin), (cx + r, cy),
         (cx + thin, cy + thin), (cx, cy + r), (cx - thin, cy + thin),
         (cx - r, cy), (cx - thin, cy - thin)],
        fill=fill,
    )


def build_mark(size: int, bg: bool = True, pad: float = 0.0,
               radius_ratio: float = 0.225) -> Image.Image:
    """Asosiy nishon. `bg=False` - shaffof fon (adaptive foreground uchun)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    if bg:
        grad = _vertical_gradient(size, BRAND_TOP, BRAND_BOTTOM).convert("RGBA")
        # Yumaloq burchakli niqob (supersampling bilan).
        ss = 4
        mask = Image.new("L", (size * ss, size * ss), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size * ss - 1, size * ss - 1],
            radius=int(size * ss * radius_ratio),
            fill=255,
        )
        grad.putalpha(mask.resize((size, size), Image.LANCZOS))
        img = Image.alpha_composite(img, grad)

    # Tomchi - oq (fon bor bo'lsa) yoki brend ko'k (fon yo'q bo'lsa).
    inner = size * (1 - pad * 2)
    drop_color = WHITE if bg else (*BRAND_TOP, 255)
    drop = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    drop_layer = Image.new("RGBA", (size, size), drop_color)
    drop_layer.putalpha(_droplet_mask(size, scale=inner / size * 0.92))
    drop = Image.alpha_composite(drop, drop_layer)

    # Tomchi ichida "porlash" - fon rangida teshik ochib, toza his beradi.
    ss = 4
    hole = Image.new("L", (size * ss, size * ss), 0)
    hd = ImageDraw.Draw(hole)
    _sparkle(hd, size * ss * 0.435, size * ss * 0.615, size * ss * 0.115, 255)
    _sparkle(hd, size * ss * 0.605, size * ss * 0.475, size * ss * 0.070, 255)
    hole = hole.resize((size, size), Image.LANCZOS)
    # Teshikni tomchidan ayiramiz.
    a = drop.getchannel("A")
    a = Image.composite(Image.new("L", (size, size), 0), a, hole)
    drop.putalpha(a)

    return Image.alpha_composite(img, drop)


def save(img: Image.Image, rel: str, size: int | None = None):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img if size is None else img.resize((size, size), Image.LANCZOS)
    out.save(path, "PNG")
    print(f"  {rel}  ({out.width}x{out.height})")


SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="CSCRM">
  <defs>
    <linearGradient id="cscrm-bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0B5FFF"/>
      <stop offset="1" stop-color="#00C2FF"/>
    </linearGradient>
    <mask id="cscrm-cut">
      <rect width="512" height="512" fill="#fff"/>
      <path d="M223 315l10-25 25-10-25-10-10-25-10 25-25 10 25 10z" fill="#000"/>
      <path d="M310 243l6-15 15-6-15-6-6-15-6 15-15 6 15 6z" fill="#000"/>
    </mask>
  </defs>
  <rect width="512" height="512" rx="115" fill="url(#cscrm-bg)"/>
  <path d="M256 108c58 74 88 122 88 158a88 88 0 1 1-176 0c0-36 30-84 88-158z"
        fill="#fff" mask="url(#cscrm-cut)"/>
</svg>
"""


# Android native splash: har bir zichlik uchun markazdagi nishon o'lchami.
# Flutter UI chizilguncha ko'rinadi, shuning uchun brend foni ustida oq
# tomchi sifatida chiziladi (fon rangi colors.xml/launch_background).
LAUNCH_DENSITIES = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}

RES = "app/android/app/src/main/res"


def build_launch_image(size: int) -> Image.Image:
    """Shaffof fonda oq tomchi - native splash uchun."""
    mark = build_mark(size, bg=False)
    white = Image.new("RGBA", mark.size, WHITE)
    white.putalpha(mark.getchannel("A"))
    return white


def main():
    print("CSCRM ikonkalari generatsiya qilinmoqda...")
    master = build_mark(S, bg=True)
    save(master, "app/assets/icon/logo.png")
    # Adaptive foreground: Android tashqi 25% ni kesadi, shuning uchun
    # nishon markazda kichikroq chiziladi.
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inner = build_mark(int(S * 0.58), bg=False)
    fg.paste(inner, (int(S * 0.21), int(S * 0.21)), inner)
    save(fg, "app/assets/icon/logo_foreground.png")

    save(master, "app/web/favicon.png", 64)
    save(master, "app/web/icons/Icon-192.png", 192)
    save(master, "app/web/icons/Icon-512.png", 512)
    # Maskable: xavfsiz zona uchun ichkarida chizilgan variant.
    mask_img = Image.new("RGBA", (S, S), (*BRAND_TOP, 255))
    small = build_mark(int(S * 0.62), bg=False)
    small_w = Image.new("RGBA", small.size, (0, 0, 0, 0))
    wl = Image.new("RGBA", small.size, WHITE)
    wl.putalpha(small.getchannel("A"))
    small_w = wl
    mask_img.paste(small_w, (int(S * 0.19), int(S * 0.19)), small_w)
    save(mask_img, "app/web/icons/Icon-maskable-192.png", 192)
    save(mask_img, "app/web/icons/Icon-maskable-512.png", 512)

    # Android native splash nishonlari (zichlik bo'yicha).
    for bucket, px in LAUNCH_DENSITIES.items():
        save(build_launch_image(px), f"{RES}/drawable-{bucket}/launch_image.png")
    # Zichligi noma'lum qurilmalar uchun zaxira.
    save(build_launch_image(216), f"{RES}/drawable/launch_image.png")

    save(master, "admin/public/favicon.png", 64)
    svg_path = os.path.join(ROOT, "admin/public/logo.svg")
    os.makedirs(os.path.dirname(svg_path), exist_ok=True)
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(SVG)
    print("  admin/public/logo.svg")
    print("Tayyor.")


if __name__ == "__main__":
    main()
