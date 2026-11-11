#!/usr/bin/env python3
"""Compose README artwork from the existing app icon and screenshots (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets'
font_path = next(Path('/System/Library/AssetsV2/com_apple_MobileAsset_Font8').glob('*/AssetData/PingFang.ttc'))

def font(size, bold=False):
    return ImageFont.truetype(str(font_path), size, index=11 if bold else 3)

def paste_shadow(canvas, image, xy, radius=32, opacity=40):
    layer = Image.new('RGBA', canvas.size)
    shadow = Image.new('RGBA', image.size, (20, 46, 50, opacity))
    shadow.putalpha(image.getchannel('A').point(lambda a: a * opacity // 255))
    layer.alpha_composite(shadow, (xy[0], xy[1] + 24))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius)))
    canvas.alpha_composite(image, xy)

icon = Image.open(ROOT / 'dist/AppIcon.iconset/icon_256x256@2x.png').convert('RGBA')
icon.save(ASSETS / 'app-icon.png')
main = Image.open(ASSETS / 'screenshot.png').convert('RGBA')
main.thumbnail((1350, 920), Image.Resampling.LANCZOS)
menu = Image.open(ASSETS / 'screenshot-menubar.png').convert('RGBA')
menu.thumbnail((370, 600), Image.Resampling.LANCZOS)
mask = Image.new('L', menu.size)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, menu.width, menu.height), 20, fill=255)
menu.putalpha(mask)

for language in ['zh', 'en']:
    canvas = Image.new('RGBA', (2400, 1260))
    pixels = canvas.load()
    for y in range(1260):
        for x in range(2400):
            blend = max(0, min(1, x / 2400 * .8 + y / 1260 * .2))
            pixels[x, y] = (int(240 - blend * 18), int(247 - blend * 10), int(247 - blend * 11), 255)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((995, 100, 2510, 1350), radius=65, fill='#D3E5E3')
    small_icon = icon.resize((116, 116), Image.Resampling.LANCZOS)
    canvas.alpha_composite(small_icon, (112, 111))
    draw.text((250, 136), 'Port Manager', font=font(48, True), fill='#172C33')
    draw.text((132, 326), '端口占用，' if language == 'zh' else 'Find what owns', font=font(116 if language == 'zh' else 88, True), fill='#172C33')
    draw.text((132, 476), '一眼找到。' if language == 'zh' else 'your port.', font=font(116 if language == 'zh' else 104, True), fill='#172C33')
    draw.text((138, 684), '查端口，看进程。' if language == 'zh' else 'Inspect ports. Stop processes.', font=font(43 if language == 'zh' else 36), fill='#52676C')
    draw.text((138, 752), '在菜单栏里，释放开发空间。' if language == 'zh' else 'Right from your Mac menu bar.', font=font(43 if language == 'zh' else 36), fill='#52676C')
    labels = ['原生 macOS', '菜单栏常驻', '免费开源'] if language == 'zh' else ['Native macOS', 'Menu bar', 'Open source']
    x = 138
    for label in labels:
        width = int(draw.textlength(label, font=font(27))) + 48
        draw.rounded_rectangle((x, 885, x + width, 946), radius=30, fill='#E0EBE9', outline='#C7DBD6', width=2)
        draw.text((x + 24, 896), label, font=font(27), fill='#285C51')
        x += width + 16
    draw.text((138, 1128), 'Apple Silicon  /  macOS 13+' , font=font(27), fill='#61797C')
    paste_shadow(canvas, main, (1015, 255))
    paste_shadow(canvas, menu, (1965, 142), radius=22, opacity=55)
    draw.text((1045, 1194), '主窗口为示例数据 · 菜单栏为实际截图' if language == 'zh' else 'Main window: example data · Menu bar: actual capture', font=font(23), fill='#61797C')
    canvas.convert('RGB').save(ASSETS / ('preview.png' if language == 'zh' else 'preview.en.png'), optimize=True)
