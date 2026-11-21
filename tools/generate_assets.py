#!/usr/bin/env python3
"""
Chronoflora Pixel Art Asset Generator
Generates all pixel art assets for the vertical slice using PIL.
Outputs to assets/images/
"""
import os
import math
import random
from PIL import Image, ImageDraw

# Palette definitions for the two eras
PALETTE_PRE_BLOOM = {
    "sky": (34, 45, 52),
    "grass": (45, 90, 60),
    "soil": (80, 60, 40),
    "water": (60, 80, 100),
    "moss": (120, 180, 100),
    "fern": (60, 110, 70),
    "biolum_cyan": (100, 220, 200),
    "biolum_violet": (180, 120, 220),
    "stone": (100, 100, 100),
    "ui_bg": (30, 30, 35),
    "ui_fg": (220, 220, 220),
    "ui_accent": (100, 220, 200),
}

PALETTE_ROOTED_AGE = {
    "sky": (255, 180, 100),
    "grass": (120, 180, 60),
    "soil": (140, 100, 60),
    "water": (100, 160, 200),
    "oak_leaf": (200, 140, 60),
    "memory_tree": (160, 100, 200),
    "sunspire": (255, 200, 80),
    "stone": (180, 140, 100),
    "ui_bg": (50, 40, 30),
    "ui_fg": (240, 220, 180),
    "ui_accent": (255, 200, 80),
}

TILE_SIZE = 16
PLAYER_SIZE = (16, 24)
PLANT_STAGE_SIZE = (16, 16)

random.seed(42)


def create_dir(path):
    os.makedirs(path, exist_ok=True)


def save(img, path):
    img.save(path, "PNG")


def draw_player_frame(draw, palette, frame, direction="down"):
    """Draw a single player animation frame."""
    w, h = PLAYER_SIZE
    cx, cy = w // 2, h // 2
    # Body (tunic)
    body_color = palette["ui_fg"]
    draw.rectangle([cx - 4, cy - 2, cx + 4, cy + 4], fill=body_color)
    # Head
    head_color = (200, 160, 120)
    draw.ellipse([cx - 3, cy - 6, cx + 3, cy], fill=head_color)
    # Arms (swing based on frame)
    arm_swing = math.sin(frame * 0.5) * 2
    draw.rectangle([cx - 6, cy - 1, cx - 3, cy + 2], fill=body_color)
    draw.rectangle([cx + 3, cy - 1 + int(arm_swing), cx + 6, cy + 2], fill=body_color)
    # Legs
    leg_swing = math.sin(frame * 0.5 + 1) * 1
    draw.rectangle([cx - 3, cy + 4, cx - 1, cy + 8], fill=(100, 80, 60))
    draw.rectangle([cx + 1, cy + 4 + int(leg_swing), cx + 3, cy + 8], fill=(100, 80, 60))
    # Lantern (held in right hand)
    lantern_y = cy - 2 + int(arm_swing)
    draw.rectangle([cx + 5, lantern_y, cx + 7, lantern_y + 3], fill=(255, 220, 100))
    draw.rectangle([cx + 6, lantern_y + 1, cx + 6, lantern_y + 1], fill=(255, 255, 150))


def generate_player_sprites(path, palette):
    """Generate player sprite sheet with walk animation."""
    frames_per_dir = 4
    directions = ["down", "up", "left", "right"]
    sheet_w = PLAYER_SIZE[0] * frames_per_dir
    sheet_h = PLAYER_SIZE[1] * len(directions)
    img = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for dir_idx, direction in enumerate(directions):
        for frame in range(frames_per_dir):
            x = dir_idx * frames_per_dir * PLAYER_SIZE[0] + frame * PLAYER_SIZE[0]
            y = dir_idx * PLAYER_SIZE[1]
            frame_img = Image.new("RGBA", PLAYER_SIZE, (0, 0, 0, 0))
            fdraw = ImageDraw.Draw(frame_img)
            draw_player_frame(fdraw, palette, frame, direction)
            img.paste(frame_img, (x, y), frame_img)

    save(img, path)


def generate_plant_sprite(path, palette, species_name, stage, era="pre_bloom"):
    """Generate a single plant growth stage sprite."""
    w, h = PLANT_STAGE_SIZE
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = w // 2

    if species_name == "Ember Moss":
        if stage == 0:  # Seed
            draw.rectangle([cx - 1, h - 2, cx + 1, h], fill=(120, 180, 100))
        elif stage == 1:  # Sprout
            draw.rectangle([cx - 1, h - 4, cx + 1, h], fill=(120, 180, 100))
            draw.ellipse([cx - 2, h - 6, cx + 2, h - 4], fill=(100, 220, 200))
        elif stage == 2:  # Mature
            draw.rectangle([cx - 1, h - 6, cx + 1, h], fill=(120, 180, 100))
            draw.ellipse([cx - 3, h - 8, cx + 3, h - 6], fill=(100, 220, 200))
            draw.ellipse([cx - 4, h - 10, cx + 4, h - 8], fill=(100, 220, 200))
        else:  # Bloom
            draw.rectangle([cx - 1, h - 8, cx + 1, h], fill=(120, 180, 100))
            for i in range(5):
                angle = i * 1.256
                px = int(cx + 4 * math.cos(angle))
                py = int(h - 10 + 4 * math.sin(angle))
                draw.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(100, 220, 200))
            draw.ellipse([cx - 3, h - 12, cx + 3, h - 6], fill=(180, 120, 220))

    elif species_name == "Whisper Fern":
        if stage == 0:
            draw.rectangle([cx - 1, h - 2, cx + 1, h], fill=(60, 110, 70))
        elif stage == 1:
            draw.rectangle([cx - 1, h - 5, cx + 1, h], fill=(60, 110, 70))
            draw.line([cx, h - 5, cx, h - 9], fill=(45, 90, 60), width=1)
        elif stage == 2:
            draw.rectangle([cx - 1, h - 8, cx + 1, h], fill=(60, 110, 70))
            draw.line([cx - 2, h - 8, cx + 2, h - 8], fill=(45, 90, 60), width=1)
            draw.line([cx, h - 8, cx, h - 12], fill=(45, 90, 60), width=1)
        else:
            draw.rectangle([cx - 1, h - 10, cx + 1, h], fill=(60, 110, 70))
            for i in range(-2, 3):
                draw.line([cx, h - 10, cx + i * 2, h - 14], fill=(45, 90, 60), width=1)
                draw.line([cx, h - 10, cx + i * 2, h - 16], fill=(45, 90, 60), width=1)
            draw.ellipse([cx - 2, h - 16, cx + 2, h - 12], fill=(100, 220, 200))

    elif species_name == "Sun-pitcher":
        if stage == 0:
            draw.rectangle([cx - 1, h - 2, cx + 1, h], fill=(140, 100, 60))
        elif stage == 1:
            draw.rectangle([cx - 1, h - 4, cx + 1, h], fill=(140, 100, 60))
            draw.rectangle([cx - 1, h - 6, cx + 1, h - 4], fill=(200, 140, 60))
        elif stage == 2:
            draw.rectangle([cx - 1, h - 8, cx + 1, h], fill=(140, 100, 60))
            draw.rectangle([cx - 2, h - 10, cx + 2, h - 6], fill=(200, 140, 60))
            draw.rectangle([cx - 1, h - 12, cx + 1, h - 10], fill=(255, 200, 80))
        else:
            draw.rectangle([cx - 1, h - 10, cx + 1, h], fill=(140, 100, 60))
            draw.rectangle([cx - 3, h - 12, cx + 3, h - 8], fill=(200, 140, 60))
            draw.rectangle([cx - 2, h - 16, cx + 2, h - 12], fill=(255, 200, 80))
            draw.ellipse([cx - 3, h - 18, cx + 3, h - 14], fill=(255, 220, 120))

    elif species_name == "Mud-lily":
        if stage == 0:
            draw.ellipse([cx - 2, h - 2, cx + 2, h], fill=(100, 220, 200))
        elif stage == 1:
            draw.ellipse([cx - 3, h - 4, cx + 3, h], fill=(100, 220, 200))
            draw.ellipse([cx - 1, h - 6, cx + 1, h - 4], fill=(60, 110, 70))
        elif stage == 2:
            draw.ellipse([cx - 4, h - 6, cx + 4, h], fill=(100, 220, 200))
            draw.ellipse([cx - 2, h - 8, cx + 2, h - 6], fill=(60, 110, 70))
            draw.rectangle([cx - 1, h - 10, cx + 1, h - 8], fill=(100, 220, 200))
        else:
            draw.ellipse([cx - 5, h - 8, cx + 5, h], fill=(100, 220, 200))
            draw.ellipse([cx - 3, h - 10, cx + 3, h - 8], fill=(60, 110, 70))
            draw.ellipse([cx - 2, h - 12, cx + 2, h - 10], fill=(180, 120, 220))
            draw.ellipse([cx - 1, h - 14, cx + 1, h - 12], fill=(255, 200, 80))

    elif species_name == "Thornvine":
        if stage == 0:
            draw.rectangle([cx - 1, h - 2, cx + 1, h], fill=(80, 60, 40))
        elif stage == 1:
            draw.rectangle([cx - 1, h - 4, cx + 1, h], fill=(80, 60, 40))
            draw.line([cx, h - 4, cx - 3, h - 7], fill=(60, 40, 20), width=1)
            draw.line([cx, h - 4, cx + 3, h - 7], fill=(60, 40, 20), width=1)
        elif stage == 2:
            draw.rectangle([cx - 1, h - 6, cx + 1, h], fill=(80, 60, 40))
            draw.line([cx, h - 6, cx - 4, h - 10], fill=(60, 40, 20), width=1)
            draw.line([cx, h - 6, cx + 4, h - 10], fill=(60, 40, 20), width=1)
            draw.line([cx - 4, h - 10, cx - 6, h - 12], fill=(60, 40, 20), width=1)
            draw.line([cx + 4, h - 10, cx + 6, h - 12], fill=(60, 40, 20), width=1)
        else:
            draw.rectangle([cx - 1, h - 8, cx + 1, h], fill=(80, 60, 40))
            draw.line([cx, h - 8, cx - 5, h - 12], fill=(60, 40, 20), width=1)
            draw.line([cx, h - 8, cx + 5, h - 12], fill=(60, 40, 20), width=1)
            draw.line([cx - 5, h - 12, cx - 8, h - 14], fill=(60, 40, 20), width=1)
            draw.line([cx + 5, h - 12, cx + 8, h - 14], fill=(60, 40, 20), width=1)
            draw.rectangle([cx - 1, h - 14, cx + 1, h - 12], fill=(180, 60, 60))

    elif species_name == "Sylthene Oak":
        if stage == 0:
            draw.rectangle([cx - 1, h - 2, cx + 1, h], fill=(200, 140, 60))
        elif stage == 1:
            draw.rectangle([cx - 1, h - 5, cx + 1, h], fill=(200, 140, 60))
            draw.rectangle([cx - 1, h - 7, cx + 1, h - 5], fill=(120, 180, 60))
        elif stage == 2:
            draw.rectangle([cx - 1, h - 10, cx + 1, h], fill=(200, 140, 60))
            draw.rectangle([cx - 2, h - 12, cx + 2, h - 8], fill=(120, 180, 60))
            draw.rectangle([cx - 1, h - 14, cx + 1, h - 10], fill=(120, 180, 60))
        else:
            draw.rectangle([cx - 1, h - 14, cx + 1, h], fill=(200, 140, 60))
            draw.rectangle([cx - 3, h - 16, cx + 3, h - 12], fill=(120, 180, 60))
            draw.rectangle([cx - 2, h - 18, cx + 2, h - 14], fill=(120, 180, 60))
            draw.rectangle([cx - 1, h - 20, cx + 1, h - 16], fill=(120, 180, 60))
            draw.ellipse([cx - 2, h - 22, cx + 2, h - 18], fill=(255, 200, 80))

    save(img, path)


def generate_tile(path, palette, tile_type):
    """Generate a 16x16 environment tile."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if tile_type == "grass_pre":
        draw.rectangle([0, 0, 15, 15], fill=palette["grass"])
        for _ in range(8):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=palette["moss"])
    elif tile_type == "soil_pre":
        draw.rectangle([0, 0, 15, 15], fill=palette["soil"])
        for _ in range(6):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=(100, 80, 50))
    elif tile_type == "water_pre":
        draw.rectangle([0, 0, 15, 15], fill=palette["water"])
        for i in range(0, 16, 4):
            draw.line([i, 0, i, 15], fill=(80, 100, 120), width=1)
    elif tile_type == "stone_pre":
        draw.rectangle([0, 0, 15, 15], fill=palette["stone"])
        for _ in range(10):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=(140, 140, 140))
    elif tile_type == "grass_rooted":
        draw.rectangle([0, 0, 15, 15], fill=palette["grass"])
        for _ in range(8):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=palette["oak_leaf"])
    elif tile_type == "soil_rooted":
        draw.rectangle([0, 0, 15, 15], fill=palette["soil"])
        for _ in range(6):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=(160, 120, 70))
    elif tile_type == "water_rooted":
        draw.rectangle([0, 0, 15, 15], fill=palette["water"])
        for i in range(0, 16, 4):
            draw.line([i, 0, i, 15], fill=(140, 180, 220), width=1)
    elif tile_type == "stone_rooted":
        draw.rectangle([0, 0, 15, 15], fill=palette["stone"])
        for _ in range(10):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            draw.point([x, y], fill=(200, 160, 120))

    save(img, path)


def generate_ui_assets(path, palette):
    """Generate UI assets: buttons, panels, icons."""
    # Button
    btn = Image.new("RGBA", (64, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(btn)
    draw.rounded_rectangle([0, 0, 63, 23], radius=3, fill=palette["ui_bg"], outline=palette["ui_fg"])
    save(btn, os.path.join(path, "button.png"))

    # Panel
    panel = Image.new("RGBA", (200, 140), (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    draw.rounded_rectangle([0, 0, 199, 139], radius=4, fill=palette["ui_bg"], outline=palette["ui_fg"])
    save(panel, os.path.join(path, "panel.png"))

    # Era indicator
    era = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(era)
    draw.rectangle([0, 0, 47, 23], fill=palette["ui_bg"], outline=palette["ui_accent"])
    save(era, os.path.join(path, "era_indicator.png"))

    # Seed packet
    seed = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(seed)
    draw.rectangle([2, 2, 14, 14], fill=palette["ui_accent"], outline=palette["ui_fg"])
    draw.line([8, 2, 8, 14], fill=palette["ui_fg"], width=1)
    save(seed, os.path.join(path, "seed_packet.png"))

    # Water droplet
    water = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(water)
    draw.ellipse([4, 4, 12, 12], fill=(100, 160, 200))
    draw.rectangle([8, 10, 8, 14], fill=(100, 160, 200))
    save(water, os.path.join(path, "water_drop.png"))


def generate_anchor_stone(path, palette):
    """Generate the Anchor Stone sprite used for era shifting."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([4, 2, 12, 14], fill=palette["stone"])
    draw.rectangle([6, 4, 10, 10], fill=palette["ui_accent"])
    draw.line([8, 4, 8, 10], fill=palette["ui_fg"], width=1)
    draw.line([6, 8, 10, 8], fill=palette["ui_fg"], width=1)
    save(img, path)


def generate_all():
    base = "assets/images"
    create_dir(base)

    # Player sprites
    create_dir(f"{base}/player")
    generate_player_sprites(f"{base}/player/keeper.png", PALETTE_PRE_BLOOM)

    # Plant sprites
    create_dir(f"{base}/plants")
    species = ["Ember Moss", "Whisper Fern", "Sun-pitcher", "Mud-lily", "Thornvine", "Sylthene Oak"]
    stages = ["seed", "sprout", "mature", "bloom"]
    for species_name in species:
        safe_name = species_name.lower().replace(" ", "_")
        for stage_idx, stage_name in enumerate(stages):
            generate_plant_sprite(
                f"{base}/plants/{safe_name}_{stage_name}.png",
                PALETTE_PRE_BLOOM,
                species_name,
                stage_idx,
                era="pre_bloom",
            )

    # Environment tiles
    create_dir(f"{base}/environments")
    for tile_type in ["grass_pre", "soil_pre", "water_pre", "stone_pre",
                      "grass_rooted", "soil_rooted", "water_rooted", "stone_rooted"]:
        palette = PALETTE_PRE_BLOOM if "pre" in tile_type else PALETTE_ROOTED_AGE
        generate_tile(f"{base}/environments/{tile_type}.png", palette, tile_type)

    # UI assets
    create_dir(f"{base}/ui")
    generate_ui_assets(f"{base}/ui", PALETTE_PRE_BLOOM)

    # Anchor Stone
    generate_anchor_stone(f"{base}/ui/anchor_stone.png", PALETTE_PRE_BLOOM)

    # Effects
    create_dir(f"{base}/effects")
    # Era shift particle
    particle = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(particle)
    draw.ellipse([2, 2, 6, 6], fill=(100, 220, 200, 200))
    save(particle, f"{base}/effects/era_particle.png")

    print(f"Assets generated in {base}/")


if __name__ == "__main__":
    generate_all()