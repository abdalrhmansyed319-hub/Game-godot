#!/usr/bin/env python3
"""
Era Manager for Chronoflora.
Handles shifting between temporal eras and cross-era state management.
"""

ERA_PRE_BLOOM = "pre_bloom"
ERA_ROOTED_AGE = "rooted_age"
ERAS = [ERA_PRE_BLOOM, ERA_ROOTED_AGE]

ERA_DISPLAY_NAMES = {
    ERA_PRE_BLOOM: "Pre-Bloom",
    ERA_ROOTED_AGE: "Rooted Age",
}

# Era order for shifting (circular)
ERA_ORDER = [ERA_PRE_BLOOM, ERA_ROOTED_AGE]


class EraManager:
    def __init__(self):
        self.current_era = ERA_PRE_BLOOM
        self.previous_era = None
        self.shift_count = 0
        self.last_shift_time = 0

    def shift_era(self):
        """Shift to the next era in the cycle."""
        self.previous_era = self.current_era
        current_index = ERA_ORDER.index(self.current_era)
        next_index = (current_index + 1) % len(ERA_ORDER)
        self.current_era = ERA_ORDER[next_index]
        self.shift_count += 1
        import time
        self.last_shift_time = time.time()

    def get_current_era(self):
        """Get the current era identifier."""
        return self.current_era

    def get_previous_era(self):
        """Get the previous era identifier."""
        return self.previous_era

    def can_shift(self, temporal_stamina):
        """Check if era shift is possible (enough stamina)."""
        return temporal_stamina >= 25

    def get_era_display_name(self, era=None):
        """Get the display name for an era."""
        era = era or self.current_era
        return ERA_DISPLAY_NAMES.get(era, era)

    def get_other_era(self):
        """Get the era that is not currently active."""
        for era in ERAS:
            if era != self.current_era:
                return era
        return None