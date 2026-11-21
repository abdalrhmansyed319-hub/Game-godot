#!/usr/bin/env python3
"""
Botanical Journal for Chronoflora.
Tracks discovered species, observations, and cross-era findings.
"""


class Journal:
    def __init__(self):
        self.discovered_species = set()
        self.observations = []  # List of (species_id, text) tuples
        self.species_notes = {}  # species_id -> list of notes
        self.root_lock_opened = False
        self.extinct_species = set()
        self.pressed_flowers = []  # List of species IDs pressed

    def discover_species(self, species_id):
        """Mark a species as discovered."""
        self.discovered_species.add(species_id)

    def add_observation(self, species_id, text):
        """Add an observation entry."""
        self.observations.append({
            "species_id": species_id,
            "text": text,
        })
        if species_id not in self.species_notes:
            self.species_notes[species_id] = []
        self.species_notes[species_id].append(text)

    def press_flower(self, species_id):
        """Press a flower specimen into the journal."""
        if species_id not in self.pressed_flowers:
            self.pressed_flowers.append(species_id)

    def get_discovered(self):
        """Get list of discovered species IDs."""
        return list(self.discovered_species)

    def get_observations_for_species(self, species_id):
        """Get all observations for a specific species."""
        return self.species_notes.get(species_id, [])

    def get_state(self):
        """Get serializable journal state."""
        return {
            "discovered_species": list(self.discovered_species),
            "observations": self.observations,
            "species_notes": self.species_notes,
            "root_lock_opened": self.root_lock_opened,
            "extinct_species": list(self.extinct_species),
            "pressed_flowers": self.pressed_flowers,
        }

    def load_state(self, state):
        """Load journal state from save data."""
        self.discovered_species = set(state.get("discovered_species", []))
        self.observations = state.get("observations", [])
        self.species_notes = state.get("species_notes", {})
        self.root_lock_opened = state.get("root_lock_opened", False)
        self.extinct_species = set(state.get("extinct_species", []))
        self.pressed_flowers = state.get("pressed_flowers", [])