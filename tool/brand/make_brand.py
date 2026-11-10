"""Mia Stream marka görsellerini üretir.

Kullanım: python3 tool/brand/make_brand.py
Harf geometrisi lib/core/mia_mark.dart ile aynıdır.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "assets/fonts/Outfit.ttf"

RED_TOP = (255, 59, 74)
RED_BOTTOM = (196, 0, 18)
WHITE = (255, 255, 255)
INK = (11, 11, 15)
INK_DEEP = (30, 6, 10)
GREY = (190, 190, 196)

# Birim: harf yüksekliği 100.
M = [(0, 100), (0, 0), (24, 0), (58, 48), (92, 0), (116, 0), (116, 100), (92, 100),
     (92, 40), (64, 80), (52, 80), (24, 40), (24, 100)]
I = [(0, 0), (24, 0), (24, 100), (0, 100)]
A_OUT = [(0, 100), (50, 0), (70, 0), (120, 100)]
A_IN = [(27, 100), (60, 34), (93, 100)]
PLAY = [(53, 69), (53, 97), (77, 83)]
M_X, I_X, A_X = 0, 132, 172
WORD_W = A_X + 120


def _shift(points, dx, scale, ox, oy):
    return [(ox + (x + dx) * scale, oy + y * scale) for x, y in points]


def _gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=color)
    return img


def draw_word(canvas, ox, oy, scale, mono=None):
    """MIA kelimesini canvas üzerine çizer. mono verilirse tek renk."""
    size = canvas.size
    white = Image.new("L", size, 0)
    red = Image.new("L", size, 0)
    play = Image.new("L", size, 0)
    dw, dr, dp = ImageDraw.Draw(white), ImageDraw.Draw(red), ImageDraw.Draw(play)
    dw.polygon(_shift(M, M_X, scale, ox, oy), fill=255)
    dw.polygon(_shift(I, I_X, scale, ox, oy), fill=255)
    dr.polygon(_shift(A_OUT, A_X, scale, ox, oy), fill=255)
    dr.polygon(_shift(A_IN, A_X, scale, ox, oy), fill=0)
    dp.polygon(_shift(PLAY, A_X, scale, ox, oy), fill=255)
    if mono is not None:
        solid = Image.new("RGBA", size, mono + (255,))
        for mask in (white, red, play):
            canvas.alpha_composite(Image.composite(solid, Image.new("RGBA", size, (0, 0, 0, 0)), mask))
        return
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow_mask = Image.eval(red, lambda v: v * 0.55).filter(ImageFilter.GaussianBlur(scale * 9))
    glow.paste(Image.new("RGBA", size, RED_TOP + (255,)), mask=glow_mask)
    canvas.alpha_composite(glow)
    canvas.paste(Image.new("RGBA", size, WHITE + (255,)), mask=white)
    top = int(oy)
    bottom = int(oy + 100 * scale) + 1
    grad = _gradient((size[0], max(1, bottom - top)), RED_TOP, RED_BOTTOM)
    full = Image.new("RGBA", size, (0, 0, 0, 0))
    full.paste(grad.convert("RGBA"), (0, top))
    canvas.paste(full, mask=red)
    canvas.paste(Image.new("RGBA", size, WHITE + (255,)), mask=play)


def draw_stream(canvas, ox, oy, width, height, color=GREY):
    """STREAM yazısını kelime genişliğine yayar."""
    font = ImageFont.truetype(str(FONT), int(height))
    try:
        font.set_variation_by_axes([600])
    except Exception:
        pass
    letters = "STREAM"
    widths = [font.getlength(ch) for ch in letters]
    gap = (width - sum(widths)) / (len(letters) - 1)
    draw = ImageDraw.Draw(canvas)
    x = ox
    for ch, w in zip(letters, widths):
        draw.text((x, oy), ch, font=font, fill=color + (255,), anchor="ls")
        x += w + gap


def logo(size, *, background=True, radius=0.22, stream=True, pad=0.17):
    """Kare uygulama simgesi."""
    ss = 4
    s = size * ss
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    if background:
        bg = _gradient((s, s), (20, 20, 26), INK)
        glow = Image.new("L", (s, s), 0)
        ImageDraw.Draw(glow).ellipse([s * 0.15, s * 0.35, s * 0.95, s * 1.15], fill=150)
        glow = glow.filter(ImageFilter.GaussianBlur(s * 0.16))
        bg.paste(Image.new("RGB", (s, s), INK_DEEP), mask=glow)
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * radius), fill=255)
        canvas.paste(bg.convert("RGBA"), mask=mask)
    inner = s * (1 - pad * 2)
    scale = inner / WORD_W
    word_h = 100 * scale
    stream_h = word_h * 0.2 if stream else 0
    gap = word_h * 0.2 if stream else 0
    total = word_h + gap + stream_h
    ox = (s - WORD_W * scale) / 2
    oy = (s - total) / 2
    draw_word(canvas, ox, oy, scale)
    if stream:
        draw_stream(canvas, ox + scale * 2, oy + word_h + gap + stream_h, WORD_W * scale - scale * 4, stream_h * 1.32)
    return canvas.resize((size, size), Image.LANCZOS)


def banner(w, h):
    """Android TV ana ekran afişi."""
    ss = 3
    W, H = w * ss, h * ss
    canvas = _gradient((W, H), (22, 22, 28), INK).convert("RGBA")
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.2, H * 0.3, W * 0.8, H * 1.3], fill=140)
    glow = glow.filter(ImageFilter.GaussianBlur(H * 0.25))
    canvas.paste(Image.new("RGBA", (W, H), INK_DEEP + (255,)), mask=glow)
    scale = (H * 0.42) / 100
    word_h = 100 * scale
    stream_h = word_h * 0.2
    gap = word_h * 0.2
    ox = (W - WORD_W * scale) / 2
    oy = (H - (word_h + gap + stream_h)) / 2
    draw_word(canvas, ox, oy, scale)
    draw_stream(canvas, ox + scale * 2, oy + word_h + gap + stream_h, WORD_W * scale - scale * 4, stream_h * 1.32)
    return canvas.resize((w, h), Image.LANCZOS)


def mark(w):
    """Saydam zemin üzerinde kelime + STREAM (açılış ekranı)."""
    ss = 3
    W = w * ss
    scale = (W * 0.86) / WORD_W
    word_h = 100 * scale
    stream_h = word_h * 0.2
    gap = word_h * 0.2
    H = int(word_h + gap + stream_h + W * 0.14)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ox = (W - WORD_W * scale) / 2
    oy = (H - (word_h + gap + stream_h)) / 2
    draw_word(canvas, ox, oy, scale)
    draw_stream(canvas, ox + scale * 2, oy + word_h + gap + stream_h, WORD_W * scale - scale * 4, stream_h * 1.32)
    return canvas.resize((w, H // ss), Image.LANCZOS)


def splash_icon(size):
    """Android 12 açılış simgesi. Daire maskesi içinde kalır."""
    return adaptive_foreground(size, inner=0.56)


def adaptive_foreground(size, inner=0.5):
    """Android uyarlanabilir simge ön yüzü. Güvenli alan merkezdeki %61."""
    ss = 4
    s = size * ss
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    inner = s * inner
    scale = inner / WORD_W
    word_h = 100 * scale
    stream_h = word_h * 0.2
    gap = word_h * 0.2
    ox = (s - WORD_W * scale) / 2
    oy = (s - (word_h + gap + stream_h)) / 2
    draw_word(canvas, ox, oy, scale)
    draw_stream(canvas, ox + scale * 2, oy + word_h + gap + stream_h, WORD_W * scale - scale * 4, stream_h * 1.32)
    return canvas.resize((size, size), Image.LANCZOS)


def save(img, path):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print("yazıldı", path.relative_to(ROOT))


def main():
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in densities.items():
        save(logo(round(48 * k)), f"android/app/src/main/res/mipmap-{name}/ic_launcher.png")
        save(adaptive_foreground(round(108 * k)), f"android/app/src/main/res/mipmap-{name}/ic_launcher_foreground.png")
    save(banner(640, 360), "android/app/src/main/res/drawable-xhdpi/banner.png")
    save(mark(480), "android/app/src/main/res/drawable-nodpi/mia_mark.png")
    save(splash_icon(432), "android/app/src/main/res/drawable-nodpi/mia_splash.png")

    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(logo(px, radius=0.225, pad=0.19), f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png")

    ico = logo(256)
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico.save(ico_path, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("yazıldı", ico_path.relative_to(ROOT))

    save(logo(32, radius=0.2, stream=False, pad=0.1), "web/favicon.png")
    save(logo(192), "web/icons/Icon-192.png")
    save(logo(512), "web/icons/Icon-512.png")
    save(logo(192, radius=0, pad=0.24), "web/icons/Icon-maskable-192.png")
    save(logo(512, radius=0, pad=0.24), "web/icons/Icon-maskable-512.png")
    save(logo(1024), "tool/brand/mia_logo_1024.png")
    save(banner(1280, 720), "tool/brand/mia_banner.png")


if __name__ == "__main__":
    main()
