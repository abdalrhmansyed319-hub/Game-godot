#!/usr/bin/env python3
"""
Player character (The Keeper) for Chronoflora.
"""
import math
import pygame


PLAYER_SIZE = (16, 24)
PLAYER_DISPLAY_SIZE = (32, 48)  # Scaled up for visibility


class Player:
    def __init__(self, x, y, assets):
        self.x = float(x)
        self.y = float(y)
        self.assets = assets
        self.direction = "down"  # down, up, left, right
        self.frame = 0
        self.frame_timer = 0
        self.moving = False

        # Load sprite sheet
        self.sprite_sheet = assets.get("player")
        self.frame_width = PLAYER_SIZE[0]
        self.frame_height = PLAYER_SIZE[1]
        self.frames_per_direction = 4

        # Direction mapping: row index in sprite sheet
        self.direction_rows = {
            "down": 0,
            "up": 1,
            "left": 2,
            "right": 3,
        }

    def update(self, dt, moving, direction):
        self.moving = moving
        if direction:
            self.direction = direction

        if moving:
            self.frame_timer += dt
            if self.frame_timer > 0.12:  # Frame duration
                self.frame_timer = 0
                self.frame = (self.frame + 1) % self.frames_per_direction
        else:
            self.frame = 0

    def draw(self, screen, camera_x, camera_y):
        """Draw the player sprite."""
        if not self.sprite_sheet:
            # Fallback: draw a colored rectangle
            pygame.draw.rect(
                screen,
                (220, 220, 220),
                (int(self.x - camera_x), int(self.y - camera_y),
                 PLAYER_DISPLAY_SIZE[0], PLAYER_DISPLAY_SIZE[1])
            )
            return

        row = self.direction_rows.get(self.direction, 0)
        col = self.frame

        # Calculate source rectangle from sprite sheet
        src_x = col * self.frame_width
        src_y = row * self.frame_height

        src_rect = pygame.Rect(src_x, src_y, self.frame_width, self.frame_height)

        # Draw scaled up
        dest_x = int(self.x - camera_x)
        dest_y = int(self.y - camera_y)

        # Create a subsurface and scale it
        frame_img = self.sprite_sheet.subsurface(src_rect)
        scaled = pygame.transform.scale(frame_img, PLAYER_DISPLAY_SIZE)
        screen.blit(scaled, (dest_x, dest_y))

    def get_rect(self):
        """Get the player's collision rectangle."""
        return pygame.Rect(
            int(self.x), int(self.y),
            PLAYER_DISPLAY_SIZE[0], PLAYER_DISPLAY_SIZE[1]
        )