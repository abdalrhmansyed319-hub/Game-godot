#!/usr/bin/env python3
"""
Chronoflora - Vertical Slice Prototype
Python/Pygame implementation of the approved GDD.
Playable prototype featuring Era 1 (Pre-Bloom) and Era 2 (Rooted Age).
"""
import sys
import os

# Add prototype directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pygame
from game import Game


def main():
    pygame.init()
    pygame.display.set_caption("Chronoflora - Vertical Slice")

    # Try to set window icon
    try:
        icon = pygame.image.load(os.path.join("..", "assets", "images", "ui", "era_indicator.png"))
        pygame.display.set_icon(icon)
    except Exception:
        pass

    game = Game()
    game.run()

    pygame.quit()


if __name__ == "__main__":
    main()