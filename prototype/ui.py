#!/usr/bin/env python3
"""
UI system for Chronoflora.
Implements HUD, Journal, Main Menu, and Pause interfaces.
"""
import pygame


SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720

ERA_PRE_BLOOM = "pre_bloom"
ERA_ROOTED_AGE = "rooted_age"

ERA_DISPLAY_NAMES = {
    ERA_PRE_BLOOM: "Pre-Bloom",
    ERA_ROOTED_AGE: "Rooted Age",
}

SEED_SPECIES_ORDER = [
    ("ember_moss", "Ember Moss"),
    ("whisper_fern", "Whisper Fern"),
    ("sun_pitcher", "Sun-pitcher"),
    ("mud_lily", "Mud-lily"),
    ("thornvine", "Thornvine"),
    ("sylthene_oak", "Sylthene Oak"),
]


class HUD:
    """Heads-up display showing era, stamina, water, and selected seed."""

    def __init__(self, assets):
        self.assets = assets
        self.font = pygame.font.Font(None, 24)
        self.font_small = pygame.font.Font(None, 20)

    def draw(self, screen, game):
        """Draw the HUD."""
        # Era indicator
        era_name = ERA_DISPLAY_NAMES.get(game.era_manager.current_era, "Unknown")
        era_text = self.font.render(f"ERA: {era_name}", True, (255, 255, 255))
        era_bg = pygame.Surface((era_text.get_width() + 20, era_text.get_height() + 10))
        era_bg.fill((0, 0, 0))
        era_bg.set_alpha(180)
        screen.blit(era_bg, (20, 20))
        screen.blit(era_text, (30, 25))

        # Temporal stamina
        stamina_text = self.font.render(
            f"STAMINA: {int(game.temporal_stamina)}/{int(game.temporal_stamina_max)}",
            True, (255, 255, 255)
        )
        stamina_bg = pygame.Surface((stamina_text.get_width() + 20, stamina_text.get_height() + 10))
        stamina_bg.fill((0, 0, 0))
        stamina_bg.set_alpha(180)
        screen.blit(stamina_bg, (20, 55))
        screen.blit(stamina_text, (30, 60))

        # Water charges
        water_text = self.font.render(
            f"WATER: {game.water_charges}/{game.water_charges_max}",
            True, (255, 255, 255)
        )
        water_bg = pygame.Surface((water_text.get_width() + 20, water_text.get_height() + 10))
        water_bg.fill((0, 0, 0))
        water_bg.set_alpha(180)
        screen.blit(water_bg, (20, 90))
        screen.blit(water_text, (30, 95))

        # Selected seed
        if game.selected_seed:
            seed_name = next(
                (name for sid, name in SEED_SPECIES_ORDER if sid == game.selected_seed),
                "Unknown"
            )
            seed_text = self.font.render(f"SEED: {seed_name}", True, (255, 255, 255))
        else:
            seed_text = self.font.render("SEED: None", True, (200, 200, 200))
        seed_bg = pygame.Surface((seed_text.get_width() + 20, seed_text.get_height() + 10))
        seed_bg.fill((0, 0, 0))
        seed_bg.set_alpha(180)
        screen.blit(seed_bg, (20, 125))
        screen.blit(seed_text, (30, 130))

        # Controls hint
        hint_text = self.font_small.render(
            "1-6: Select Seed | W: Water | E: Shift Era | J: Journal | ESC: Pause",
            True, (180, 180, 180)
        )
        screen.blit(hint_text, (20, SCREEN_HEIGHT - 30))

    def handle_click(self, pos):
        """Handle HUD clicks. Returns True if handled."""
        return False


class JournalUI:
    """Botanical Journal interface."""

    def __init__(self, assets, journal):
        self.assets = assets
        self.journal = journal
        self.font = pygame.font.Font(None, 24)
        self.font_small = pygame.font.Font(None, 20)
        self.scroll_offset = 0
        self.selected_species = None

    def draw(self, screen):
        """Draw the journal interface."""
        # Background panel
        panel = pygame.Surface((700, 500))
        panel.fill((40, 35, 45))
        panel.set_alpha(230)
        screen.blit(panel, (SCREEN_WIDTH // 2 - 350, SCREEN_HEIGHT // 2 - 250))

        # Title
        title = self.font.render("BOTANICAL JOURNAL", True, (255, 220, 180))
        screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, SCREEN_HEIGHT // 2 - 220))

        # Species list (left side)
        list_x = SCREEN_WIDTH // 2 - 320
        list_y = SCREEN_HEIGHT // 2 - 180
        list_w = 200

        species_label = self.font_small.render("Discovered Species:", True, (200, 200, 200))
        screen.blit(species_label, (list_x, list_y))

        y_offset = list_y + 30
        for i, species_id in enumerate(self.journal.get_discovered()):
            species_data = __import__("plant").PLANT_SPECIES.get(species_id, {})
            name = species_data.get("name", species_id)
            color = (255, 255, 255) if self.selected_species == species_id else (180, 180, 180)
            text = self.font_small.render(f"{i+1}. {name}", True, color)
            screen.blit(text, (list_x, y_offset + i * 25))

        # Details panel (right side)
        detail_x = SCREEN_WIDTH // 2 + 20
        detail_y = SCREEN_HEIGHT // 2 - 180

        if self.selected_species:
            species_data = __import__("plant").PLANT_SPECIES.get(self.selected_species, {})
            name = species_data.get("name", self.selected_species)

            name_text = self.font.render(name, True, (255, 220, 180))
            screen.blit(name_text, (detail_x, detail_y))

            eras = species_data.get("era_availability", [])
            era_names = []
            for e in eras:
                if e == "pre_bloom":
                    era_names.append("Pre-Bloom")
                elif e == "rooted_age":
                    era_names.append("Rooted Age")
            era_text = self.font_small.render(f"Eras: {', '.join(era_names)}", True, (180, 180, 180))
            screen.blit(era_text, (detail_x, detail_y + 30))

            # Observations
            obs_label = self.font_small.render("Observations:", True, (200, 200, 200))
            screen.blit(obs_label, (detail_x, detail_y + 60))

            observations = self.journal.get_observations_for_species(self.selected_species)
            for i, obs in enumerate(observations[-5:]):  # Show last 5
                obs_text = self.font_small.render(f"- {obs['text']}", True, (160, 160, 160))
                screen.blit(obs_text, (detail_x, detail_y + 85 + i * 20))
        else:
            no_sel = self.font_small.render("Select a species to view details", True, (180, 180, 180))
            screen.blit(no_sel, (detail_x, detail_y))

        # Instructions
        inst = self.font_small.render("Press J or ESC to close", True, (150, 150, 150))
        screen.blit(inst, (SCREEN_WIDTH // 2 - inst.get_width() // 2, SCREEN_HEIGHT // 2 + 220))

    def handle_click(self, pos):
        """Handle journal clicks."""
        # Simple species selection from list
        list_x = SCREEN_WIDTH // 2 - 320
        list_y = SCREEN_HEIGHT // 2 - 150
        for i, species_id in enumerate(self.journal.get_discovered()):
            if (list_x <= pos[0] <= list_x + 200 and
                    list_y + i * 25 <= pos[1] <= list_y + i * 25 + 20):
                self.selected_species = species_id
                return True
        return False


class MainMenuUI:
    """Main menu interface."""

    def __init__(self, assets):
        self.assets = assets
        self.font = pygame.font.Font(None, 48)
        self.font_small = pygame.font.Font(None, 28)
        self.menu_items = ["NEW GAME", "CONTINUE", "QUIT"]
        self.selected = 0

    def draw(self, screen):
        """Draw the main menu."""
        screen.fill((20, 20, 30))

        # Title
        title = self.font.render("CHRONOFLORA", True, (100, 220, 200))
        title_shadow = self.font.render("CHRONOFLORA", True, (40, 80, 80))
        screen.blit(title_shadow, (SCREEN_WIDTH // 2 - title.get_width() // 2 + 3, 153))
        screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 150))

        subtitle = self.font_small.render("A Temporal Botanical Simulation", True, (200, 200, 200))
        screen.blit(subtitle, (SCREEN_WIDTH // 2 - subtitle.get_width() // 2, 210))

        # Menu items
        y = 320
        for i, item in enumerate(self.menu_items):
            color = (255, 255, 255) if i == self.selected else (120, 120, 120)
            text = self.font_small.render(item, True, color)
            screen.blit(text, (SCREEN_WIDTH // 2 - text.get_width() // 2, y))
            y += 50

        # Controls
        controls = self.font_small.render("Use UP/DOWN to select, ENTER to confirm", True, (150, 150, 150))
        screen.blit(controls, (SCREEN_WIDTH // 2 - controls.get_width() // 2, 520))

    def handle_click(self, pos):
        """Handle menu clicks."""
        return False

    def handle_key(self, key):
        """Handle keyboard navigation."""
        if key == pygame.K_UP:
            self.selected = (self.selected - 1) % len(self.menu_items)
        elif key == pygame.K_DOWN:
            self.selected = (self.selected + 1) % len(self.menu_items)
        elif key == pygame.K_RETURN:
            return self.menu_items[self.selected]
        return None


class PauseUI:
    """Pause menu interface."""

    def __init__(self, assets):
        self.assets = assets
        self.font = pygame.font.Font(None, 48)
        self.font_small = pygame.font.Font(None, 28)
        self.menu_items = ["RESUME", "SAVE", "LOAD", "QUIT TO MENU"]
        self.selected = 0

    def draw(self, screen):
        """Draw the pause menu overlay."""
        # Dim background
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        overlay.fill((0, 0, 0))
        overlay.set_alpha(180)
        screen.blit(overlay, (0, 0))

        # Panel
        panel = pygame.Surface((400, 300))
        panel.fill((40, 35, 45))
        panel.set_alpha(230)
        screen.blit(panel, (SCREEN_WIDTH // 2 - 200, SCREEN_HEIGHT // 2 - 150))

        # Title
        title = self.font.render("PAUSED", True, (255, 220, 180))
        screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, SCREEN_HEIGHT // 2 - 110))

        # Menu items
        y = SCREEN_HEIGHT // 2 - 40
        for i, item in enumerate(self.menu_items):
            color = (255, 255, 255) if i == self.selected else (180, 180, 180)
            text = self.font_small.render(item, True, color)
            screen.blit(text, (SCREEN_WIDTH // 2 - text.get_width() // 2, y))
            y += 50

    def handle_click(self, pos):
        """Handle pause menu clicks."""
        return None

    def handle_key(self, key):
        """Handle keyboard navigation."""
        if key == pygame.K_UP:
            self.selected = (self.selected - 1) % len(self.menu_items)
        elif key == pygame.K_DOWN:
            self.selected = (self.selected + 1) % len(self.menu_items)
        elif key == pygame.K_RETURN:
            return self.menu_items[self.selected]
        return None