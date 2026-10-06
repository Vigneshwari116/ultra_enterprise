#!/usr/bin/env python3
"""Generate launcher icons from assets/images/ultra_logo.png (bill letterhead logo)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/images/ultra_logo.png"


def _fit_on_square(src: Image.Image, size: int, padding: float = 0.1, bg: tuple[int, int, int, int] | None = None) -> Image.Image:
    src = src.convert("RGBA")
    canvas = Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))
    inner = int(size * (1 - 2 * padding))
    ratio = min(inner / src.width, inner / src.height)
    w, h = max(1, int(src.width * ratio)), max(1, int(src.height * ratio))
    resized = src.resize((w, h), Image.Resampling.LANCZOS)
    x, y = (size - w) // 2, (size - h) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def _legacy_icon(src: Image.Image, size: int) -> Image.Image:
    square = _fit_on_square(src, size, padding=0.12, bg=(255, 255, 255, 255))
    return square.convert("RGB")


def _foreground_icon(src: Image.Image, size: int) -> Image.Image:
    return _fit_on_square(src, size, padding=0.15, bg=(0, 0, 0, 0))


def _write_png(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def android_icons(src: Image.Image) -> None:
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res = ROOT / "android/app/src/main/res"
    for folder, px in densities.items():
        _write_png(res / folder / "ic_launcher.png", _legacy_icon(src, px))
        _write_png(res / folder / "ic_launcher_foreground.png", _foreground_icon(src, px))


def ios_icons(src: Image.Image) -> None:
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
        _write_png(out / name, _legacy_icon(src, px))


def macos_icons(src: Image.Image) -> None:
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
        _write_png(out / name, _legacy_icon(src, px))


def web_icons(src: Image.Image) -> None:
    out = ROOT / "web/icons"
    for name, px in {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }.items():
        pad = 0.18 if "maskable" in name else 0.12
        img = _fit_on_square(src, px, padding=pad, bg=(255, 255, 255, 255)).convert("RGB")
        _write_png(out / name, img)


def windows_icon(src: Image.Image) -> None:
    path = ROOT / "windows/runner/resources/app_icon.ico"
    sizes = [16, 32, 48, 64, 128, 256]
    images = [_legacy_icon(src, s) for s in sizes]
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
    android_icons(logo)
    ios_icons(logo)
    macos_icons(logo)
    web_icons(logo)
    windows_icon(logo)
    print("Generated ULTRA launcher icons for Android, iOS, macOS, web, and Windows.")


if __name__ == "__main__":
    main()
