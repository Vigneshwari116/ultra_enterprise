#!/usr/bin/env python3
"""Generate sharp launcher icons from the bill logo (assets/images/ultra_logo.png)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/images/ultra_logo.png"
MASTER_PATH = ROOT / "assets/images/ultra_app_icon_master.png"
MASTER_SIZE = 1024


def _crisp_resize(src: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Upscale line-art logos in 2x steps (nearest) then smooth once — sharper than single LANCZOS blow-up."""
    cur = src.convert("RGBA")
    while cur.width < target_w and cur.height < target_h:
        nw = min(cur.width * 2, target_w)
        nh = min(cur.height * 2, target_h)
        if nw == cur.width and nh == cur.height:
            break
        cur = cur.resize((nw, nh), Image.Resampling.NEAREST)
    return cur.resize((target_w, target_h), Image.Resampling.LANCZOS)


def _remove_white_background(img: Image.Image, threshold: int = 245) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                pixels[x, y] = (255, 255, 255, 0)
    return rgba


def _build_master(src: Image.Image) -> Image.Image:
    """One high-res square master; all platform sizes are downscaled from this."""
    src = src.convert("RGBA")
    # Fill most of the icon so the logo stays readable on the home screen.
    fill = 0.9
    target_w = int(MASTER_SIZE * fill)
    target_h = max(1, int(target_w * src.height / src.width))
    if target_h > int(MASTER_SIZE * fill):
        target_h = int(MASTER_SIZE * fill)
        target_w = max(1, int(target_h * src.width / src.height))

    upscaled = _crisp_resize(src, target_w, target_h)
    upscaled = upscaled.filter(ImageFilter.UnsharpMask(radius=1.6, percent=180, threshold=2))

    legacy = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (255, 255, 255, 255))
    x = (MASTER_SIZE - target_w) // 2
    y = (MASTER_SIZE - target_h) // 2
    legacy.alpha_composite(upscaled, (x, y))
    return legacy


def _build_master_foreground(src: Image.Image) -> Image.Image:
    cutout = _remove_white_background(src)
    fill = 0.82
    target_w = int(MASTER_SIZE * fill)
    target_h = max(1, int(target_w * cutout.height / cutout.width))
    if target_h > int(MASTER_SIZE * fill):
        target_h = int(MASTER_SIZE * fill)
        target_w = max(1, int(target_h * cutout.width / cutout.height))

    upscaled = _crisp_resize(cutout, target_w, target_h)
    upscaled = upscaled.filter(ImageFilter.UnsharpMask(radius=1.6, percent=180, threshold=2))

    fg = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    x = (MASTER_SIZE - target_w) // 2
    y = (MASTER_SIZE - target_h) // 2
    fg.alpha_composite(upscaled, (x, y))
    return fg


def _resize_master(master: Image.Image, size: int, as_rgb: bool = False) -> Image.Image:
    out = master.resize((size, size), Image.Resampling.LANCZOS)
    if as_rgb:
        bg = Image.new("RGB", (size, size), (255, 255, 255))
        bg.paste(out, mask=out.split()[3] if out.mode == "RGBA" else None)
        return bg
    return out


def _write_png(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", compress_level=6)


def android_icons(legacy_master: Image.Image, fg_master: Image.Image) -> None:
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res = ROOT / "android/app/src/main/res"
    for folder, px in densities.items():
        _write_png(res / folder / "ic_launcher.png", _resize_master(legacy_master, px, as_rgb=True))
        _write_png(res / folder / "ic_launcher_foreground.png", _resize_master(fg_master, px))


def ios_icons(legacy_master: Image.Image) -> None:
    out = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    mapping = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in mapping.items():
        _write_png(out / name, _resize_master(legacy_master, px, as_rgb=True))


def macos_icons(legacy_master: Image.Image) -> None:
    out = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    mapping = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for name, px in mapping.items():
        _write_png(out / name, _resize_master(legacy_master, px, as_rgb=True))


def web_icons(legacy_master: Image.Image) -> None:
    out = ROOT / "web/icons"
    for name, px in {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }.items():
        _write_png(out / name, _resize_master(legacy_master, px, as_rgb=True))


def windows_icon(legacy_master: Image.Image) -> None:
    path = ROOT / "windows/runner/resources/app_icon.ico"
    sizes = [16, 32, 48, 64, 128, 256]
    images = [_resize_master(legacy_master, s, as_rgb=True) for s in sizes]
    path.parent.mkdir(parents=True, exist_ok=True)
    images[0].save(
        path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:],
    )


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source logo: {SRC}")
    logo = Image.open(SRC)
    legacy_master = _build_master(logo)
    fg_master = _build_master_foreground(logo)
    _write_png(MASTER_PATH, legacy_master)

    android_icons(legacy_master, fg_master)
    ios_icons(legacy_master)
    macos_icons(legacy_master)
    web_icons(legacy_master)
    windows_icon(legacy_master)
    print(f"Wrote master {MASTER_SIZE}px -> {MASTER_PATH.relative_to(ROOT)}")
    print("Regenerated launcher icons (downscaled from master for sharpness).")


if __name__ == "__main__":
    main()
