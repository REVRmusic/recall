#!/usr/bin/env python3
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_dmg_background(output_dir="Resources"):
    os.makedirs(output_dir, exist_ok=True)
    
    # Dimensions Retina : 1320 x 840 px (correspond à une fenêtre Finder de 660 x 420 pt de zone de contenu)
    W, H = 1320, 840
    
    # 1. Base gradient de fond
    img = Image.new("RGBA", (W, H), (11, 14, 20, 255))
    draw = ImageDraw.Draw(img)
    
    for y in range(H):
        ratio = y / float(H)
        # Dégradé subtil du bleu nuit profond (#0A0D14) vers un ardoise élégant (#121726)
        r = int(10 + ratio * 12)
        g = int(13 + ratio * 15)
        b = int(20 + ratio * 24)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))
        
    # 2. Halo lumineux radial sous les deux icônes et le centre
    # Centre Y légèrement rehaussé pour laisser respirer le bas (cy = 380 px / 190 pt)
    cx, cy = 350, 380
    ax, ay = 970, 380
    
    glow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    
    # Anneaux subtils de disque vinyle en arrière-plan centré sur l'icône de Recall
    for radius in range(85, 260, 25):
        glow_draw.ellipse(
            [(cx - radius, cy - radius), (cx + radius, cy + radius)],
            outline=(0, 240, 255, 14),
            width=2
        )
        
    # Halo néon cyan sous Recall
    for rad in range(160, 20, -10):
        alpha = int((1.0 - rad / 160.0) * 35)
        glow_draw.ellipse(
            [(cx - rad, cy - rad), (cx + rad, cy + rad)],
            fill=(0, 240, 255, alpha)
        )
        
    # Halo sous Applications
    for rad in range(160, 20, -10):
        alpha = int((1.0 - rad / 160.0) * 30)
        glow_draw.ellipse(
            [(ax - rad, cy - rad), (ax + rad, cy + rad)],
            fill=(99, 102, 241, alpha)
        )
        
    img = Image.alpha_composite(img, glow_layer)
    draw = ImageDraw.Draw(img)
    
    # 3. Flèche stylisée reliant Recall -> Applications
    arrow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    arrow_draw = ImageDraw.Draw(arrow_layer)
    
    arrow_start = (485, 385)
    arrow_end = (825, 385)
    
    points = []
    steps = 80
    for i in range(steps + 1):
        t = i / float(steps)
        px = arrow_start[0] + (arrow_end[0] - arrow_start[0]) * t
        py = arrow_start[1] - math.sin(t * math.pi) * 32
        points.append((px, py))
        
    # Halo flou de la flèche
    for i in range(len(points) - 1):
        arrow_draw.line([points[i], points[i+1]], fill=(0, 240, 255, 80), width=14)
    arrow_layer = arrow_layer.filter(ImageFilter.GaussianBlur(radius=6))
    arrow_draw = ImageDraw.Draw(arrow_layer)
    
    # Ligne centrale nette cyan néon vers violet
    for i in range(len(points) - 1):
        t = i / float(len(points))
        cr = int(0 + t * 160)
        cg = int(240 - t * 100)
        cb = int(255)
        arrow_draw.line([points[i], points[i+1]], fill=(cr, cg, cb, 230), width=6)
        
    # Pointe de flèche
    tip_x, tip_y = arrow_end
    arrow_head = [
        (tip_x + 15, tip_y),
        (tip_x - 22, tip_y - 20),
        (tip_x - 14, tip_y),
        (tip_x - 22, tip_y + 20),
    ]
    arrow_draw.polygon(arrow_head, fill=(160, 140, 255, 255))
    img = Image.alpha_composite(img, arrow_layer)
    draw = ImageDraw.Draw(img)
    
    # 4. Typographie & Titres
    font_title = None
    font_sub = None
    font_badge = None
    
    font_paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf"
    ]
    for fp in font_paths:
        try:
            font_title = ImageFont.truetype(fp, 54)
            font_sub = ImageFont.truetype(fp, 25)
            font_badge = ImageFont.truetype(fp, 23)
            break
        except Exception:
            continue
            
    if not font_title:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        font_badge = ImageFont.load_default()
        
    # Titre "Recall" centré avec point cyan néon
    title_text = "Recall"
    title_bbox = draw.textbbox((0, 0), title_text, font=font_title)
    tw = title_bbox[2] - title_bbox[0]
    tx = (W - tw) // 2 - 12
    ty = 60
    
    draw.text((tx + 2, ty + 2), title_text, font=font_title, fill=(0, 0, 0, 180))
    draw.text((tx, ty), title_text, font=font_title, fill=(255, 255, 255, 255))
    
    dot_x = tx + tw + 10
    dot_y = ty + 36
    draw.ellipse([(dot_x - 6, dot_y - 6), (dot_x + 6, dot_y + 6)], fill=(0, 240, 255, 255))
    draw.ellipse([(dot_x - 12, dot_y - 12), (dot_x + 12, dot_y + 12)], outline=(0, 240, 255, 120), width=2)
    
    # Sous-titre
    sub_text = "Pour Serato DJ Pro & Pioneer Rekordbox"
    sub_bbox = draw.textbbox((0, 0), sub_text, font=font_sub)
    sw = sub_bbox[2] - sub_bbox[0]
    sx = (W - sw) // 2
    sy = 130
    draw.text((sx, sy), sub_text, font=font_sub, fill=(160, 175, 200, 210))
    
    # 5. Badge d'instruction (centré, relevé à y = 600 px pour être visible au-dessus de la barre d'état)
    badge_text = "Glissez l'icône Recall dans le dossier Applications"
    badge_bbox = draw.textbbox((0, 0), badge_text, font=font_badge)
    bw = badge_bbox[2] - badge_bbox[0]
    bx = (W - bw) // 2
    by = 610
    
    pad_x = 28
    pad_y = 12
    pill_rect = [bx - pad_x, by - pad_y, bx + bw + pad_x, by + (badge_bbox[3] - badge_bbox[1]) + pad_y]
    
    pill_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_layer)
    pill_draw.rounded_rectangle(pill_rect, radius=24, fill=(255, 255, 255, 16), outline=(255, 255, 255, 45), width=1)
    img = Image.alpha_composite(img, pill_layer)
    draw = ImageDraw.Draw(img)
    
    draw.text((bx, by), badge_text, font=font_badge, fill=(235, 242, 255, 255))
    
    # Sauvegarde Retina 2x
    retina_path = os.path.join(output_dir, "dmg_background@2x.png")
    img.save(retina_path, "PNG")
    
    # Sauvegarde Standard 1x (660 x 420)
    std_path = os.path.join(output_dir, "dmg_background.png")
    img_std = img.resize((660, 420), Image.Resampling.LANCZOS)
    img_std.save(std_path, "PNG")
    
    print(f"✅ Images d'arrière-plan DMG générées avec succès :")
    print(f"   • Retina : {retina_path} (1320x840)")
    print(f"   • Standard : {std_path} (660x420)")

if __name__ == "__main__":
    create_dmg_background()
