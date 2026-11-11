#!/usr/bin/env python3
"""Compose the committed sharing card from existing artwork (macOS + Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUTPUT = REPO / 'website/public/social-preview.png'
FONT = next(Path('/System/Library/AssetsV2/com_apple_MobileAsset_Font8').glob('*/AssetData/PingFang.ttc'))

def font(size, bold=False):
    return ImageFont.truetype(str(FONT), size, index=11 if bold else 3)

canvas = Image.new('RGBA', (1200, 630), '#F8F9F6')
draw = ImageDraw.Draw(canvas)
icon = Image.open(REPO / 'assets/app-icon.png').convert('RGBA')
icon.thumbnail((62, 62), Image.Resampling.LANCZOS)
canvas.alpha_composite(icon, (64, 54))
draw.text((142, 58), '端口管家', font=font(28, True), fill='#263E33')
draw.text((145, 96), 'PORT MANAGER', font=font(11), fill='#7A8F70')
draw.text((62, 198), '我没开啊。', font=font(76, True), fill='#202C29')
draw.text((62, 298), '端口谁占的？', font=font(76, True), fill='#24654E')
draw.text((69, 428), '谁开的、哪来的？挨个查户口。', font=font(23), fill='#849477')
draw.rounded_rectangle((68, 509, 364, 561), radius=8, fill='#24654E')
draw.text((93, 522), '原生 macOS · 免费开源', font=font(20, True), fill='#F8FBF3')

draw.rounded_rectangle((620, 64, 1240, 586), radius=26, fill='#E8EDDF')
draw.text((650, 87), 'LOCALHOST / 野生住户登记处', font=font(14), fill='#81916F')
screenshot = Image.open(REPO / 'assets/screenshot.png').convert('RGBA')
screenshot.thumbnail((750, 520), Image.Resampling.LANCZOS)
shadow = Image.new('RGBA', canvas.size)
mask = screenshot.getchannel('A').point(lambda alpha: alpha * 30 // 255)
shadow.paste(Image.new('RGBA', screenshot.size, '#233B29'), (644, 156), mask)
canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(16)))
canvas.alpha_composite(screenshot, (644, 141))

badge = Image.new('RGBA', (218, 66))
badge_draw = ImageDraw.Draw(badge)
badge_draw.rounded_rectangle((1, 1, 217, 65), radius=10, fill='#FFFEF9', outline='#DBE4CF', width=2)
badge_draw.ellipse((20, 29, 27, 36), fill='#779A5F')
badge_draw.text((40, 19), ':3000', font=font(22, True), fill='#567648')
badge_draw.text((119, 24), '不明住户', font=font(15), fill='#8C9C7A')
badge = badge.rotate(-6, expand=True, resample=Image.Resampling.BICUBIC)
canvas.alpha_composite(badge, (947, 414))
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.convert('RGB').save(OUTPUT, optimize=True)
print(OUTPUT)
