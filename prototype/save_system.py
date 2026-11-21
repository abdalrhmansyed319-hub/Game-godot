#!/usr/bin/env python3
"""
Save/Load system for Chronoflora.
Handles persistent game state using JSON files.
"""
import os
import json


class SaveSystem:
    def __init__(self):
        self.save_dir = os.path.join("..", "saves")
        self.save_file = os.path.join(self.save_dir, "savegame.json")
        os.makedirs(self.save_dir, exist_ok=True)

    def save_exists(self):
        """Check if a save file exists."""
        return os.path.exists(self.save_file)

    def save_game(self, game):
        """Save the current game state."""
        state = game.get_state_for_save()
        try:
            with open(self.save_file, "w") as f:
                json.dump(state, f, indent=2)
            return True
        except Exception as e:
            print(f"Save error: {e}")
            return False

    def load_game(self, game):
        """Load game state into the game object."""
        if not self.save_exists():
            return False
        try:
            with open(self.save_file, "r") as f:
                state = json.load(f)
            game.load_state_from_save(state)
            return True
        except Exception as e:
            print(f"Load error: {e}")
            return False

    def delete_save(self):
        """Delete the save file."""
        if self.save_exists():
            os.remove(self.save_file)