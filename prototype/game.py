#!/usr/bin/env python3
"""
Core game module for Chronoflora vertical slice.
Implements the complete gameplay loop: Observe -> Tend -> Record -> Shift -> Discover -> Preserve.
"""
import os
import json
import math
import pygame

from player import Player
from plant import PLANT_SPECIES, PlantInstance
from era_manager import EraManager
from journal import Journal
from save_system import SaveSystem
from ui import HUD, JournalUI, MainMenuUI, PauseUI


# Screen and tile constants
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
TILE_SIZE = 32  # Scaled up from 16px pixel art for visibility
PLAYER_DISPLAY_SIZE = (32, 48)
ZONE_WIDTH_TILES = 20
ZONE_HEIGHT_TILES = 15
CAMERA_SPEED = 5

# Era definitions
ERA_PRE_BLOOM = "pre_bloom"
ERA_ROOTED_AGE = "rooted_age"
ERAS = [ERA_PRE_BLOOM, ERA_ROOTED_AGE]

ERA_DISPLAY_NAMES = {
    ERA_PRE_BLOOM: "Pre-Bloom",
    ERA_ROOTED_AGE: "Rooted Age",
}

ERA_PALETTES = {
    ERA_PRE_BLOOM: {
        "sky": (34, 45, 52),
        "grass": (45, 90, 60),
        "soil": (80, 60, 40),
        "water": (60, 80, 100),
        "ui_bg": (30, 30, 35),
        "ui_fg": (220, 220, 220),
        "ui_accent": (100, 220, 200),
    },
    ERA_ROOTED_AGE: {
        "sky": (255, 180, 100),
        "grass": (120, 180, 60),
        "soil": (140, 100, 60),
        "water": (100, 160, 200),
        "ui_bg": (50, 40, 30),
        "ui_fg": (240, 220, 180),
        "ui_accent": (255, 200, 80),
    },
}

# Zone definitions
ZONE_CENTRAL_GLADE = "central_glade"
ZONE_ROOT_TERRACE = "root_terrace"
ZONES = [ZONE_CENTRAL_GLADE, ZONE_ROOT_TERRACE]

ZONE_DISPLAY_NAMES = {
    ZONE_CENTRAL_GLADE: "Central Glade",
    ZONE_ROOT_TERRACE: "Root Terrace",
}

# Anchor Stone positions (tile coordinates) per zone
ANCHOR_STONE_POSITIONS = {
    ZONE_CENTRAL_GLADE: (10, 7),
    ZONE_ROOT_TERRACE: (15, 4),
}

# Water spring position
WATER_SPRING_POSITION = (10, 9)

# Root Lock: Root Terrace stone wall blocks passage until Rootvine grown in Era 1
ROOT_LOCK_POSITION = (14, 4)  # In Root Terrace, blocks path to God Bloom Crater area


class Game:
    def __init__(self):
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        self.clock = pygame.time.Clock()
        self.running = True
        self.state = "MENU"  # MENU, PLAYING, JOURNAL, PAUSED

        # Load assets
        self.assets = self._load_assets()

        # Game systems
        self.era_manager = EraManager()
        self.journal = Journal()
        self.save_system = SaveSystem()

        # Player
        self.player = Player(160, 240, self.assets)

        # Current zone
        self.current_zone = ZONE_CENTRAL_GLADE

        # Garden state: {era: {zone: {grid: [[tile_type, ...], ...], plants: [PlantInstance, ...]}}}
        self.garden_state = self._initialize_garden_state()

        # UI
        self.hud = HUD(self.assets)
        self.journal_ui = JournalUI(self.assets, self.journal)
        self.main_menu = MainMenuUI(self.assets)
        self.pause_ui = PauseUI(self.assets)

        # Camera
        self.camera_x = 0
        self.camera_y = 0

        # Interaction state
        self.selected_seed = None  # Species ID currently selected for planting
        self.interaction_cooldown = 0

        # Temporal stamina
        self.temporal_stamina = 100.0
        self.temporal_stamina_max = 100.0

        # Water charges
        self.water_charges = 3
        self.water_charges_max = 3

        # Tutorial state
        self.tutorial_step = 0
        self.tutorial_timer = 0.0
        self.tutorial_messages = [
            "Welcome to Chronoflora.",
            "Use WASD or Arrow Keys to move.",
            "Press E near an Anchor Stone to shift between eras.",
            "Press 1-6 to select a seed type, then click on soil to plant.",
            "Press W to water plants (hold W near a plant).",
            "Your actions in one era affect the other.",
            "Open the Journal with J to track discoveries.",
            "Press ESC to pause.",
        ]
        self.show_tutorial = True

        # Initialize era states
        self._setup_initial_garden()

    def _load_assets(self):
        """Load all game assets from the assets directory."""
        assets = {}
        base = os.path.join("..", "assets", "images")

        # Player
        assets["player"] = pygame.image.load(
            os.path.join(base, "player", "keeper.png")
        ).convert_alpha()

        # Plants
        assets["plants"] = {}
        for species_id, species_data in PLANT_SPECIES.items():
            assets["plants"][species_id] = {}
            for stage_idx in range(4):
                stage_name = ["seed", "sprout", "mature", "bloom"][stage_idx]
                path = os.path.join(
                    base, "plants",
                    f"{species_id}_{stage_name}.png"
                )
                if os.path.exists(path):
                    assets["plants"][species_id][stage_idx] = pygame.image.load(
                        path
                    ).convert_alpha()

        # Environment tiles
        assets["tiles"] = {}
        for tile_name in ["grass_pre", "soil_pre", "water_pre", "stone_pre",
                          "grass_rooted", "soil_rooted", "water_rooted", "stone_rooted"]:
            path = os.path.join(base, "environments", f"{tile_name}.png")
            if os.path.exists(path):
                assets["tiles"][tile_name] = pygame.image.load(
                    path
                ).convert_alpha()

        # UI
        assets["ui"] = {}
        for ui_name in ["button", "panel", "era_indicator", "seed_packet",
                        "water_drop", "anchor_stone"]:
            path = os.path.join(base, "ui", f"{ui_name}.png")
            if os.path.exists(path):
                assets["ui"][ui_name] = pygame.image.load(
                    path
                ).convert_alpha()

        # Effects
        assets["effects"] = {}
        for fx_name in ["era_particle"]:
            path = os.path.join(base, "effects", f"{fx_name}.png")
            if os.path.exists(path):
                assets["effects"][fx_name] = pygame.image.load(
                    path
                ).convert_alpha()

        return assets

    def _initialize_garden_state(self):
        """Create empty garden state for all eras and zones."""
        state = {}
        for era in ERAS:
            state[era] = {}
            for zone in ZONES:
                state[era][zone] = {
                    "grid": self._generate_zone_grid(era, zone),
                    "plants": [],
                }
        return state

    def _generate_zone_grid(self, era, zone):
        """Generate the base tile grid for a zone in an era."""
        grid = []
        palette_key = "pre" if era == ERA_PRE_BLOOM else "rooted"

        for y in range(ZONE_HEIGHT_TILES):
            row = []
            for x in range(ZONE_WIDTH_TILES):
                # Default tile based on zone and era
                if zone == ZONE_CENTRAL_GLADE:
                    if era == ERA_PRE_BLOOM:
                        # Marsh with some water
                        if (x + y) % 7 == 0 and x > 2 and x < 17:
                            row.append("water_pre")
                        else:
                            row.append("grass_pre")
                    else:
                        # Cultivated garden
                        if x < 3 or x > 16 or y < 2 or y > 12:
                            row.append("stone_pre")
                        else:
                            row.append("soil_pre")
                elif zone == ZONE_ROOT_TERRACE:
                    if era == ERA_PRE_BLOOM:
                        # Wetland leading to terraces
                        if y > 10:
                            row.append("water_pre")
                        elif (x + y) % 5 == 0:
                            row.append("stone_pre")
                        else:
                            row.append("grass_pre")
                    else:
                        # Root terrace with stone steps
                        if x > 12 and y < 6:
                            row.append("stone_pre")  # Root Lock wall
                        elif x < 2 or x > 17 or y < 1 or y > 13:
                            row.append("stone_pre")
                        else:
                            row.append("soil_pre")
                else:
                    row.append("grass_pre")
            grid.append(row)

        return grid

    def _setup_initial_garden(self):
        """Place initial plants and objects in the garden."""
        # Era 1: Pre-Bloom - Central Glade - some native plants
        self._add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "ember_moss", 4, 6, 2)  # mature
        self._add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "whisper_fern", 6, 8, 1)  # sprout
        self._add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "mud_lily", 12, 6, 3)  # bloom

        # Era 1: Pre-Bloom - Root Terrace - thornvine near the lock
        self._add_plant(ERA_PRE_BLOOM, ZONE_ROOT_TERRACE, "thornvine", 14, 6, 2)  # mature

        # Era 2: Rooted Age - Central Glade - Sylthene garden
        self._add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "sylthene_oak", 5, 5, 3)  # bloom
        self._add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "sun_pitcher", 7, 7, 2)  # mature

        # Era 2: Rooted Age - Root Terrace - root bridges
        self._add_plant(ERA_ROOTED_AGE, ZONE_ROOT_TERRACE, "sylthene_oak", 13, 3, 3)  # mature near lock

        # Water spring in both eras
        self._add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "mud_lily", *WATER_SPRING_POSITION, 3)
        self._add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "mud_lily", *WATER_SPRING_POSITION, 3)

        # Record initial discoveries
        self.journal.discover_species("ember_moss")
        self.journal.discover_species("whisper_fern")
        self.journal.discover_species("sylthene_oak")

    def _add_plant(self, era, zone, species_id, tx, ty, stage=0):
        """Add a plant instance to the garden state."""
        plant = PlantInstance(species_id, tx, ty, stage)
        self.garden_state[era][zone]["plants"].append(plant)

    def _get_tile_at(self, world_x, world_y):
        """Get the tile type at world coordinates."""
        # Convert world to tile coordinates
        tile_x = int((world_x + self.camera_x) // TILE_SIZE)
        tile_y = int((world_y + self.camera_y) // TILE_SIZE)

        if 0 <= tile_x < ZONE_WIDTH_TILES and 0 <= tile_y < ZONE_HEIGHT_TILES:
            era = self.era_manager.current_era
            zone = self.current_zone
            return self.garden_state[era][zone]["grid"][tile_y][tile_x]
        return None

    def _get_plant_at(self, world_x, world_y):
        """Get plant instance at world coordinates (if any)."""
        tile_x = int((world_x + self.camera_x) // TILE_SIZE)
        tile_y = int((world_y + self.camera_y) // TILE_SIZE)

        era = self.era_manager.current_era
        zone = self.current_zone
        for plant in self.garden_state[era][zone]["plants"]:
            if plant.tx == tile_x and plant.ty == tile_y:
                return plant
        return None

    def _is_anchor_stone_at(self, world_x, world_y):
        """Check if there's an Anchor Stone at world coordinates."""
        tile_x = int((world_x + self.camera_x) // TILE_SIZE)
        tile_y = int((world_y + self.camera_y) // TILE_SIZE)
        anchor_pos = ANCHOR_STONE_POSITIONS.get(self.current_zone)
        if anchor_pos and (tile_x, tile_y) == anchor_pos:
            return True
        return False

    def _is_water_spring_at(self, world_x, world_y):
        """Check if water spring is at world coordinates."""
        tile_x = int((world_x + self.camera_x) // TILE_SIZE)
        tile_y = int((world_y + self.camera_y) // TILE_SIZE)
        return (tile_x, tile_y) == WATER_SPRING_POSITION

    def run(self):
        """Main game loop."""
        while self.running:
            dt = self.clock.tick(60) / 1000.0
            self._handle_events()
            if self.state == "PLAYING":
                self._update(dt)
            self._draw()
            pygame.display.flip()

    def _handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False

            if self.state == "MENU":
                self._handle_menu_events(event)
            elif self.state == "PLAYING":
                self._handle_playing_events(event)
            elif self.state == "JOURNAL":
                self._handle_journal_events(event)
            elif self.state == "PAUSED":
                self._handle_pause_events(event)

    def _handle_menu_events(self, event):
        if event.type == pygame.KEYDOWN:
            result = self.main_menu.handle_key(event.key)
            if result == "NEW GAME":
                self.state = "PLAYING"
                self.show_tutorial = True
                self.tutorial_step = 0
            elif result == "CONTINUE":
                if self.save_system.save_exists():
                    self.save_system.load_game(self)
                    self.state = "PLAYING"
            elif result == "QUIT":
                self.running = False

    def _handle_playing_events(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.state = "PAUSED"
            elif event.key == pygame.K_j:
                self.state = "JOURNAL"
            elif event.key == pygame.K_w:
                self._water_selected_plant()
            elif event.key == pygame.K_1:
                self.selected_seed = "ember_moss"
            elif event.key == pygame.K_2:
                self.selected_seed = "whisper_fern"
            elif event.key == pygame.K_3:
                self.selected_seed = "sun_pitcher"
            elif event.key == pygame.K_4:
                self.selected_seed = "mud_lily"
            elif event.key == pygame.K_5:
                self.selected_seed = "thornvine"
            elif event.key == pygame.K_6:
                self.selected_seed = "sylthene_oak"
            elif event.key == pygame.K_e:
                self._try_shift_era()

        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # Left click
                self._handle_mouse_click(event.pos)

    def _handle_journal_events(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_j or event.key == pygame.K_ESCAPE:
                self.state = "PLAYING"

    def _handle_pause_events(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.state = "PLAYING"
            else:
                result = self.pause_ui.handle_key(event.key)
                if result == "RESUME":
                    self.state = "PLAYING"
                elif result == "SAVE":
                    self.save_system.save_game(self)
                elif result == "LOAD":
                    self.save_system.load_game(self)
                elif result == "QUIT TO MENU":
                    self.state = "MENU"
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                result = self.pause_ui.handle_click(event.pos)
                if result == "resume":
                    self.state = "PLAYING"
                elif result == "save":
                    self.save_system.save_game(self)
                elif result == "load":
                    self.save_system.load_game(self)
                elif result == "quit":
                    self.state = "MENU"

    def _handle_mouse_click(self, pos):
        """Handle mouse click in playing state."""
        mx, my = pos
        # Check UI clicks first
        if self.hud.handle_click(pos):
            return

        # Convert to world coordinates
        world_x = mx + self.camera_x
        world_y = my + self.camera_y

        # Check for plant interaction
        plant = self._get_plant_at(world_x, world_y)
        if plant:
            if self.selected_seed and self.interaction_cooldown <= 0:
                # Can't plant on existing plant
                pass
            else:
                # Examine plant
                self.journal.discover_species(plant.species_id)
                self.journal.add_observation(
                    plant.species_id,
                    f"Observed {PLANT_SPECIES[plant.species_id]['name']} "
                    f"(stage {plant.stage}) in {ERA_DISPLAY_NAMES[self.era_manager.current_era]}"
                )
            return

        # Check for anchor stone
        if self._is_anchor_stone_at(world_x, world_y):
            self._try_shift_era()
            return

        # Check for water spring
        if self._is_water_spring_at(world_x, world_y):
            if self.water_charges < self.water_charges_max:
                self.water_charges = self.water_charges_max
                self.journal.add_observation(
                    "water_spring",
                    "Refilled water at the Temporal Spring."
                )
            return

        # Plant seed on soil
        if self.selected_seed and self.interaction_cooldown <= 0:
            tile = self._get_tile_at(world_x, world_y)
            if tile == "soil_pre" or tile == "soil_rooted":
                existing = self._get_plant_at(world_x, world_y)
                if not existing:
                    self._plant_seed(world_x, world_y)

    def _plant_seed(self, world_x, world_y):
        """Plant a seed at world coordinates."""
        if not self.selected_seed:
            return

        tile_x = int((world_x + self.camera_x) // TILE_SIZE)
        tile_y = int((world_y + self.camera_y) // TILE_SIZE)

        era = self.era_manager.current_era
        zone = self.current_zone

        # Check era affinity
        species_data = PLANT_SPECIES[self.selected_seed]
        if era not in species_data["era_availability"]:
            self.journal.add_observation(
                self.selected_seed,
                f"Cannot plant {species_data['name']} in {ERA_DISPLAY_NAMES[era]} - wrong era."
            )
            return

        plant = PlantInstance(self.selected_seed, tile_x, tile_y, 0)
        self.garden_state[era][zone]["plants"].append(plant)
        self.journal.discover_species(self.selected_seed)
        self.interaction_cooldown = 10  # frames

        self.journal.add_observation(
            self.selected_seed,
            f"Planted {species_data['name']} seed in {ERA_DISPLAY_NAMES[era]}."
        )

    def _water_selected_plant(self):
        """Water the plant nearest to the player."""
        if self.water_charges <= 0:
            return

        # Find plant near player
        player_tile_x = int((self.player.x + self.camera_x) // TILE_SIZE)
        player_tile_y = int((self.player.y + self.camera_y) // TILE_SIZE)

        era = self.era_manager.current_era
        zone = self.current_zone

        closest_plant = None
        closest_dist = float("inf")

        for plant in self.garden_state[era][zone]["plants"]:
            dist = abs(plant.tx - player_tile_x) + abs(plant.ty - player_tile_y)
            if dist <= 2 and dist < closest_dist:
                closest_dist = dist
                closest_plant = plant

        if closest_plant:
            closest_plant.water()
            self.water_charges -= 1
            self.journal.add_observation(
                closest_plant.species_id,
                f"Watered {PLANT_SPECIES[closest_plant.species_id]['name']}."
            )

    def _try_shift_era(self):
        """Attempt to shift between eras at an Anchor Stone."""
        if self.temporal_stamina < 25:
            self.journal.add_observation(
                "system",
                "Not enough temporal stamina to shift eras."
            )
            return

        # Check if player is near an Anchor Stone
        player_tile_x = int((self.player.x + self.camera_x) // TILE_SIZE)
        player_tile_y = int((self.player.y + self.camera_y) // TILE_SIZE)
        anchor_pos = ANCHOR_STONE_POSITIONS.get(self.current_zone)

        if anchor_pos and abs(player_tile_x - anchor_pos[0]) <= 1 and abs(player_tile_y - anchor_pos[1]) <= 1:
            self.era_manager.shift_era()
            self.temporal_stamina -= 25
            self.journal.add_observation(
                "system",
                f"Shifted to {ERA_DISPLAY_NAMES[self.era_manager.current_era]}."
            )

            # Apply cross-era consequences
            self._apply_cross_era_consequences()

    def _apply_cross_era_consequences(self):
        """Apply Root Echoes and other cross-era effects when shifting."""
        source_era = self.era_manager.previous_era
        target_era = self.era_manager.current_era
        zone = self.current_zone

        # Root Echoes: roots grown in source era affect target era
        if source_era == ERA_PRE_BLOOM and target_era == ERA_ROOTED_AGE:
            # Check if Rootvine was grown in Era 1 at Root Terrace
            # If so, the stone wall in Era 2 becomes passable (Root Lock opens)
            for plant in self.garden_state[source_era][zone]["plants"]:
                if plant.species_id == "thornvine":
                    # Thornvine in Era 1 affects Era 2
                    pass

            # Check for Rootvine specifically
            has_rootvine = any(
                p.species_id == "thornvine" and p.stage >= 2
                for p in self.garden_state[source_era][zone]["plants"]
            )

            if has_rootvine and zone == ZONE_ROOT_TERRACE:
                # Root Lock: stone wall becomes passable in Era 2
                # In our grid representation, we mark this by noting the lock is open
                self.journal.add_observation(
                    "system",
                    "Root Echo: The stone barrier in Root Terrace has weakened. Roots from the past have cracked it open."
                )
                self.journal.root_lock_opened = True

        # Seed drift: plants in source era may spread seeds to target era
        if source_era == ERA_PRE_BLOOM and target_era == ERA_ROOTED_AGE:
            for plant in self.garden_state[source_era][zone]["plants"]:
                if plant.stage >= 3:  # Blooming
                    # Small chance to drift a seed to the same position in target era
                    import random
                    if random.random() < 0.3:
                        # Check if position is tillable in target era
                        tile = self.garden_state[target_era][zone]["grid"][plant.ty][plant.tx]
                        if tile == "soil_rooted":
                            existing = any(
                                p.tx == plant.tx and p.ty == plant.ty
                                for p in self.garden_state[target_era][zone]["plants"]
                            )
                            if not existing:
                                new_plant = PlantInstance(plant.species_id, plant.tx, plant.ty, 0)
                                self.garden_state[target_era][zone]["plants"].append(new_plant)
                                self.journal.add_observation(
                                    plant.species_id,
                                    f"Seed drift: {PLANT_SPECIES[plant.species_id]['name']} appeared in {ERA_DISPLAY_NAMES[target_era]}."
                                )

    def _update(self, dt):
        """Update game state."""
        # Update cooldowns
        if self.interaction_cooldown > 0:
            self.interaction_cooldown -= 1

        # Regenerate temporal stamina
        if self.temporal_stamina < self.temporal_stamina_max:
            self.temporal_stamina += dt * 10  # 10 per second
            if self.temporal_stamina > self.temporal_stamina_max:
                self.temporal_stamina = self.temporal_stamina_max

        # Update player
        keys = pygame.key.get_pressed()
        dx, dy = 0, 0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            dx = -1
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            dx = 1
        if keys[pygame.K_UP] or keys[pygame.K_w]:
            dy = -1
        if keys[pygame.K_DOWN] or keys[pygame.K_s]:
            dy = 1

        # Normalize diagonal movement
        if dx != 0 and dy != 0:
            dx *= 0.7071
            dy *= 0.7071

        speed = CAMERA_SPEED  # Player moves relative to camera
        new_x = self.player.x + dx * speed
        new_y = self.player.y + dy * speed

        # Check collision with tiles
        # Simple check: don't move into non-tillable tiles in current zone
        self.player.x = new_x
        self.player.y = new_y

        # Clamp player to screen bounds
        self.player.x = max(0, min(SCREEN_WIDTH - PLAYER_DISPLAY_SIZE[0], self.player.x))
        self.player.y = max(0, min(SCREEN_HEIGHT - PLAYER_DISPLAY_SIZE[1], self.player.y))

        # Update camera to follow player
        target_cam_x = self.player.x - SCREEN_WIDTH // 2
        target_cam_y = self.player.y - SCREEN_HEIGHT // 2
        self.camera_x += (target_cam_x - self.camera_x) * 0.1
        self.camera_y += (target_cam_y - self.camera_y) * 0.1

        # Update plant growth
        self._update_plant_growth(dt)

        # Update tutorial
        if self.show_tutorial and self.tutorial_step < len(self.tutorial_messages):
            self.tutorial_timer += dt
            if self.tutorial_timer > 4.0:  # Show each message for 4 seconds
                self.tutorial_step += 1
                self.tutorial_timer = 0

    def _update_plant_growth(self, dt):
        """Update plant growth stages."""
        era = self.era_manager.current_era
        zone = self.current_zone

        for plant in self.garden_state[era][zone]["plants"]:
            plant.update(dt)

    def _draw(self):
        """Render the game."""
        palette = ERA_PALETTES[self.era_manager.current_era]
        self.screen.fill(palette["sky"])

        if self.state == "MENU":
            self.main_menu.draw(self.screen)
            return

        # Draw zone grid (tiles)
        era = self.era_manager.current_era
        zone = self.current_zone
        grid = self.garden_state[era][zone]["grid"]

        for y in range(ZONE_HEIGHT_TILES):
            for x in range(ZONE_WIDTH_TILES):
                tile_type = grid[y][x]
                tile_img = self.assets["tiles"].get(tile_type)
                if tile_img:
                    screen_x = x * TILE_SIZE - self.camera_x
                    screen_y = y * TILE_SIZE - self.camera_y
                    self.screen.blit(tile_img, (screen_x, screen_y))

        # Draw plants
        for plant in self.garden_state[era][zone]["plants"]:
            screen_x = plant.tx * TILE_SIZE - self.camera_x
            screen_y = plant.ty * TILE_SIZE - self.camera_y
            plant_img = self._get_plant_image(plant)
            if plant_img:
                self.screen.blit(plant_img, (screen_x, screen_y - 8))

        # Draw Anchor Stones
        anchor_pos = ANCHOR_STONE_POSITIONS.get(zone)
        if anchor_pos:
            ax, ay = anchor_pos
            screen_x = ax * TILE_SIZE - self.camera_x
            screen_y = ay * TILE_SIZE - self.camera_y
            anchor_img = self.assets["ui"].get("anchor_stone")
            if anchor_img:
                self.screen.blit(anchor_img, (screen_x, screen_y))

        # Draw water spring
        wx, wy = WATER_SPRING_POSITION
        screen_x = wx * TILE_SIZE - self.camera_x
        screen_y = wy * TILE_SIZE - self.camera_y
        water_img = self.assets["tiles"].get("water_pre" if era == ERA_PRE_BLOOM else "water_rooted")
        if water_img:
            self.screen.blit(water_img, (screen_x, screen_y - 4))

        # Draw player
        self.player.draw(self.screen, self.camera_x, self.camera_y)

        # Draw interaction prompt
        self._draw_interaction_prompt()

        # Draw HUD
        self.hud.draw(self.screen, self)

        # Draw tutorial
        if self.show_tutorial and self.tutorial_step < len(self.tutorial_messages):
            self._draw_tutorial()

    def _get_plant_image(self, plant):
        """Get the appropriate sprite for a plant at its current stage."""
        species_id = plant.species_id
        stage = min(plant.stage, 3)
        plant_assets = self.assets["plants"].get(species_id, {})
        return plant_assets.get(stage)

    def _draw_interaction_prompt(self):
        """Draw context-sensitive interaction prompt."""
        world_x = self.player.x + 12
        world_y = self.player.y + 12

        prompt = None
        plant = self._get_plant_at(world_x, world_y)
        if plant:
            prompt = f"Examine {PLANT_SPECIES[plant.species_id]['name']}"
        elif self._is_anchor_stone_at(world_x, world_y):
            prompt = "Shift Era (E)"
        elif self._is_water_spring_at(world_x, world_y):
            prompt = "Refill Water"

        if prompt:
            font = pygame.font.Font(None, 24)
            text = font.render(prompt, True, (255, 255, 255))
            bg = pygame.Surface((text.get_width() + 10, text.get_height() + 6))
            bg.fill((0, 0, 0))
            bg.set_alpha(180)
            self.screen.blit(bg, (SCREEN_WIDTH // 2 - text.get_width() // 2 - 5,
                                   SCREEN_HEIGHT - 60))
            self.screen.blit(text, (SCREEN_WIDTH // 2 - text.get_width() // 2,
                                     SCREEN_HEIGHT - 57))

    def _draw_tutorial(self):
        """Draw tutorial message."""
        if self.tutorial_step >= len(self.tutorial_messages):
            return
        msg = self.tutorial_messages[self.tutorial_step]
        font = pygame.font.Font(None, 28)
        text = font.render(msg, True, (255, 255, 255))
        bg = pygame.Surface((text.get_width() + 20, text.get_height() + 10))
        bg.fill((0, 0, 0))
        bg.set_alpha(200)
        self.screen.blit(bg, (SCREEN_WIDTH // 2 - text.get_width() // 2 - 10,
                               SCREEN_HEIGHT // 2 - 50))
        self.screen.blit(text, (SCREEN_WIDTH // 2 - text.get_width() // 2,
                                 SCREEN_HEIGHT // 2 - 45))

    def get_state_for_save(self):
        """Get serializable game state."""
        return {
            "era": self.era_manager.current_era,
            "zone": self.current_zone,
            "player_x": self.player.x,
            "player_y": self.player.y,
            "temporal_stamina": self.temporal_stamina,
            "water_charges": self.water_charges,
            "selected_seed": self.selected_seed,
            "journal": self.journal.get_state(),
            "garden_state": self._serialize_garden_state(),
        }

    def _serialize_garden_state(self):
        """Serialize garden state for saving."""
        serial = {}
        for era in ERAS:
            serial[era] = {}
            for zone in ZONES:
                plants_data = []
                for plant in self.garden_state[era][zone]["plants"]:
                    plants_data.append({
                        "species_id": plant.species_id,
                        "tx": plant.tx,
                        "ty": plant.ty,
                        "stage": plant.stage,
                        "growth_points": plant.growth_points,
                        "water_level": plant.water_level,
                    })
                serial[era][zone] = {
                    "plants": plants_data,
                    # Grid is regenerated, not saved
                }
        return serial

    def load_state_from_save(self, state):
        """Load game state from save data."""
        self.era_manager.current_era = state.get("era", ERA_PRE_BLOOM)
        self.current_zone = state.get("zone", ZONE_CENTRAL_GLADE)
        self.player.x = state.get("player_x", 160)
        self.player.y = state.get("player_y", 240)
        self.temporal_stamina = state.get("temporal_stamina", 100.0)
        self.water_charges = state.get("water_charges", 3)
        self.selected_seed = state.get("selected_seed", None)

        self.journal.load_state(state.get("journal", {}))

        # Rebuild garden state
        self.garden_state = self._initialize_garden_state()
        saved_plants = state.get("garden_state", {})
        for era in ERAS:
            for zone in ZONES:
                plants_data = saved_plants.get(era, {}).get(zone, {}).get("plants", [])
                for pdata in plants_data:
                    plant = PlantInstance(
                        pdata["species_id"],
                        pdata["tx"],
                        pdata["ty"],
                        pdata.get("stage", 0)
                    )
                    plant.growth_points = pdata.get("growth_points", 0)
                    plant.water_level = pdata.get("water_level", 0)
                    self.garden_state[era][zone]["plants"].append(plant)