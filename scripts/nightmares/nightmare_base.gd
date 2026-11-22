class_name NightmareBase
extends CharacterBody2D
## NightmareBase — a nightmare creature (GDD 6 and 7).
##
## Holds health, the Manifest/Revealed duality, stagger, anchoring, and the
## Resolution offer. Behaviour lives in NightmareAI so a creature's *stats and
## story* stay in data while its *behaviour* stays tunable in one place.

signal died(nightmare_id: StringName)
signal revealed_state_changed(is_revealed: bool)
signal staggered(amount: float)
signal resolution_offered(nightmare_id: StringName, options: Array[int])

@export var data: NightmareData = null
## Fallback when no Resource is assigned in the inspector.
@export var nightmare_id: StringName = &""

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var ai: Node = $AI
@onready var status: StatusEffectSystem = $Status

var health: float = 0.0
var is_dead: bool = false
var is_revealed: bool = false
var reveal_timer: float = 0.0
var is_anchored: bool = false
var anchor_timer: float = 0.0
var weak_point_exposed: bool = false
var stagger_accumulator: float = 0.0
var is_staggered: bool = false
var stagger_timer: float = 0.0
## Per-encounter phase/resolution logic. RefCounted, owned by this node.
var _resolution_manager: BossEncounterManager = null
var _visual: NightmareVisual = null
## Squash/stretch applied on impact and eased back out. Cheap, and it is the
## single biggest contributor to hits feeling connected.
var _impact_squash: Vector2 = Vector2.ONE
var _knockback_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("nightmares")
	if data == null and nightmare_id != &"":
		data = NightmareDatabase.nightmare(nightmare_id)
	if data == null:
		push_error("NightmareBase '%s' has no NightmareData assigned" % name)
		return
	health = data.max_health
	hurtbox.owner_path = get_path()
	hitbox.owner_path = get_path()
	hitbox.damage = data.attack_damage
	hitbox.kind = Hitbox.Kind.ENEMY
	hitbox.counterable = true
	hitbox.deactivate()
	_build_visual()
	GameManager.discover_clue(StringName("sighting"), data.id)
	if data.journal_entry_on_discovery != "":
		JournalManager.discover(
			StringName("nightmare_" + String(data.id)),
			JournalManager.Category.NIGHTMARE,
			data.display_name,
			data.journal_entry_on_discovery
		)


func _process(delta: float) -> void:
	if is_revealed:
		reveal_timer -= delta
		if reveal_timer <= 0.0:
			set_revealed(false, 0.0)
	if is_anchored:
		anchor_timer -= delta
		if anchor_timer <= 0.0:
			set_anchored(false, 0.0)
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
	# Easing the squash back to neutral rather than snapping: a hard reset is
	# what makes hit reactions look mechanical.
	_impact_squash = _impact_squash.lerp(Vector2.ONE, clampf(delta * 11.0, 0.0, 1.0))
	if _visual != null:
		_visual.scale = _impact_squash


## Folds knockback into the body velocity.
##
## NightmareAI drives deliberate movement and calls `move_and_slide()`; this
## only *adds* an impulse and lets it decay, so a shove reads as a shove
## instead of teleporting the creature. Decay is framerate-independent.
func _physics_process(delta: float) -> void:
	if is_dead or _knockback_velocity.length_squared() < 1.0:
		return
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 1400.0)


# --- Hit reaction -----------------------------------------------------------
## Called by DamageSystem. `strength` is normalised around 1.0 for a heavy hit.
func hit_react(strength: float, _point: Vector2) -> void:
	if is_dead:
		return
	# Anchored nightmares refuse to move — that is the entire point of the Anchor.
	var squash: float = clampf(strength * 0.22, 0.0, 0.34)
	_impact_squash = Vector2(1.0 + squash, 1.0 - squash)
	if _visual != null:
		_visual.flash()


func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead or is_anchored:
		return
	# Mass matters: a Warden should not fly across the room off a light hit.
	_knockback_velocity += Vector2(direction.x, -0.55) * (force / data.mass)


func revealed_spark_color() -> Color:
	# Revealed nightmares throw gold sparks. Reserved colour, earned.
	return data.revealed_color if is_revealed else Palette.BLOODLESS_IMPACT


# --- Damage -----------------------------------------------------------------
func take_damage(amount: float, _result: Dictionary) -> bool:
	if is_dead:
		return false
	health -= amount
	if health <= 0.0:
		health = 0.0
		_on_defeated()
		return true
	return false


func apply_stagger(amount: float) -> void:
	stagger_accumulator += amount
	staggered.emit(amount)
	if stagger_accumulator >= data.stagger_threshold:
		stagger_accumulator = 0.0
		is_staggered = true
		stagger_timer = 0.85
		if hitbox != null:
			hitbox.deactivate()


## Interrupts the current telegraphed ability (Lantern, Anchor or counter).
func interrupt_current_ability() -> bool:
	if is_dead:
		return false
	if hitbox != null and hitbox.is_active:
		hitbox.deactivate()
	if ai != null and ai.has_method("interrupt"):
		return bool(ai.interrupt())
	return is_staggered


# --- Revealed state (GDD 6) -------------------------------------------------
func set_revealed(value: bool, duration: float) -> void:
	if is_dead:
		return
	is_revealed = value
	reveal_timer = duration
	hurtbox.damage_taken_multiplier = data.damage_multiplier_when_revealed if value else 1.0
	_tint_for_state()
	revealed_state_changed.emit(value)
	if value and data.journal_entry_on_understanding != "":
		JournalManager.discover(
			StringName("understood_" + String(data.id)),
			JournalManager.Category.WEAKNESS,
			"%s — what it really is" % data.display_name,
			data.journal_entry_on_understanding
		)


## The Lantern exposes the true vulnerability (GDD 4B, 6).
func expose_weak_point() -> void:
	if is_dead:
		return
	weak_point_exposed = true
	set_revealed(true, 4.0)
	Fx.reveal_ring(self, global_position + Vector2(0, -22.0))
	AudioManager.play_named(&"lantern")


## Mimics lose their borrowed shape (Echo of Borrowed Faces).
func unmask(duration: float) -> void:
	if data.category == NightmareData.Category.MIMIC:
		set_revealed(true, duration)


# --- Anchor (GDD 4C) --------------------------------------------------------
func set_anchored(value: bool, duration: float) -> void:
	is_anchored = value
	anchor_timer = duration


func can_teleport() -> bool:
	return data.can_teleport and not is_anchored


# --- Resolution (GDD 6, Stage 7) --------------------------------------------
func _on_defeated() -> void:
	if is_dead:
		return
	is_dead = true
	if hitbox != null:
		hitbox.deactivate()
	AudioManager.play_named(&"resolution")
	died.emit(data.id)
	# The Hunter may now decide its fate rather than simply killing it.
	_offer_resolution()


func _offer_resolution() -> void:
	# Held on the node so the RefCounted manager stays alive while the prompt
	# is open. Created per encounter, discarded with the nightmare.
	_resolution_manager = BossEncounterManager.new()
	var options: Array[int] = _resolution_manager.available_resolutions(data)
	resolution_offered.emit(data.id, options)
	var player: Node = _find_player()
	if player != null and player.has_method("offer_resolution"):
		player.offer_resolution(self, options)


func resolve(resolution: int) -> void:
	if _resolution_manager == null:
		_resolution_manager = BossEncounterManager.new()
	_resolution_manager.choose(resolution)
	AudioManager.play_named(&"resolution")
	queue_free()


func _find_player() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


# --- Interaction ------------------------------------------------------------
func can_interact() -> bool:
	return is_dead or weak_point_exposed


func interact_with(_player: Node) -> void:
	if is_dead:
		_offer_resolution()
		return
	if weak_point_exposed:
		# Interacting with the revealed vulnerability is the real kill (GDD 6).
		health -= data.max_health * 0.5
		if health <= 0.0:
			_on_defeated()


func normalised_health() -> float:
	return clampf(health / data.max_health, 0.0, 1.0) if data != null else 0.0


# --- Visuals ----------------------------------------------------------------
## The creature is drawn in code by NightmareVisual: a distinct silhouette per
## category, the telegraph as part of the body, and the revealed core in the
## reserved gold. It replaces the coloured rectangles from the prototype.
func _build_visual() -> void:
	_visual = NightmareVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	_visual.bind(self)


## Kept as a named hook so callers do not need to know about the visual node.
func _tint_for_state() -> void:
	if _visual != null:
		_visual.queue_redraw()
