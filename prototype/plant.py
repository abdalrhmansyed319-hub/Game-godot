#!/usr/bin/env python3
"""
Plant system for Chronoflora.
Defines plant species data, growth stages, and plant instances.
"""

ERA_PRE_BLOOM = "pre_bloom"
ERA_ROOTED_AGE = "rooted_age"

# Plant species definitions
# Each species has: name, era_availability, growth requirements, special properties
PLANT_SPECIES = {
    "ember_moss": {
        "name": "Ember Moss",
        "era_availability": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
        "growth_time": [2, 5, 8, 12],  # Days per stage
        "water_need": 1,
        "soil_quality_min": 0,
        "special": "bioluminescent",
        "cross_era_behavior": "roots_glow",
    },
    "whisper_fern": {
        "name": "Whisper Fern",
        "era_availability": [ERA_PRE_BLOOM],
        "growth_time": [3, 6, 10, 15],
        "water_need": 2,
        "soil_quality_min": 0,
        "special": "sound_dampening",
        "cross_era_behavior": "fossilizes",
    },
    "sun_pitcher": {
        "name": "Sun-pitcher",
        "era_availability": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
        "growth_time": [2, 4, 7, 10],
        "water_need": 3,
        "soil_quality_min": 1,
        "special": "carnivorous",
        "cross_era_behavior": "petrifies",
    },
    "mud_lily": {
        "name": "Mud-lily",
        "era_availability": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
        "growth_time": [2, 4, 6, 9],
        "water_need": 4,  # Aquatic
        "soil_quality_min": 0,
        "special": "aquatic",
        "cross_era_behavior": "lily_pads",
    },
    "thornvine": {
        "name": "Thornvine",
        "era_availability": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
        "growth_time": [1, 3, 6, 10],
        "water_need": 1,
        "soil_quality_min": 0,
        "special": "invasive",
        "cross_era_behavior": "root_echo_cracks_stone",
    },
    "sylthene_oak": {
        "name": "Sylthene Oak",
        "era_availability": [ERA_ROOTED_AGE],
        "growth_time": [5, 10, 20, 30],
        "water_need": 2,
        "soil_quality_min": 3,
        "special": "memory_tree_host",
        "cross_era_behavior": "petrifies",
    },
}

# Growth stage names
GROWTH_STAGES = ["seed", "sprout", "mature", "bloom"]


class PlantInstance:
    """A single plant instance in the garden."""

    def __init__(self, species_id, tx, ty, stage=0):
        self.species_id = species_id
        self.tx = tx  # Tile X
        self.ty = ty  # Tile Y
        self.stage = stage  # 0=seed, 1=sprout, 2=mature, 3=bloom
        self.growth_points = 0.0
        self.water_level = 0
        self.days_in_stage = 0.0
        self.extinct = False

    def update(self, dt):
        """Update plant growth. Called every frame."""
        if self.stage >= 3:  # Already bloomed
            return

        species = PLANT_SPECIES.get(self.species_id)
        if not species:
            return

        # Accumulate growth points (1 GP per second base rate)
        # Watering and era climate modify this
        self.growth_points += dt * 0.1  # Base growth rate
        self.days_in_stage += dt

        # Check if ready to advance stage
        stage_days = species["growth_time"][self.stage]
        # Convert days to seconds (1 game day = 60 real seconds for prototype)
        seconds_per_day = 60.0
        required_seconds = stage_days * seconds_per_day

        if self.days_in_stage >= required_seconds:
            self.advance_stage()

    def advance_stage(self):
        """Advance to the next growth stage."""
        if self.stage < 3:
            self.stage += 1
            self.days_in_stage = 0.0
            self.growth_points = 0.0

    def water(self):
        """Apply water to the plant."""
        self.water_level = min(self.water_level + 1, 3)
        # Watering boosts growth
        self.growth_points += 0.5

    def is_blooming(self):
        """Check if plant is in bloom stage."""
        return self.stage >= 3

    def get_display_name(self):
        """Get the human-readable name of the species."""
        return PLANT_SPECIES[self.species_id]["name"]