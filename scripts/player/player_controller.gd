class_name PlayerController
extends CharacterBody2D
## PlayerController — the Hunter (GDD 3, 4, 5).
##
## Owns input routing and the visual. All feel lives in PlayerMovement, all
## combat in PlayerCombat, all instruments in their own nodes, so each system
## can be tuned independently.

signal interaction_available(target: Node)
signal interaction_cleared
signal resolution_prompt_opened(nightmare: Node, options: Array[int])

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var health: PlayerHealth = $Health
@onready var lantern: PlayerLantern = $Lantern
@onready var anchor: PlayerAnchor = $Anchor
@onready var abilities: PlayerAbilities = $Abilities
@onready var status: StatusEffectSystem = $Status
@onready var resonance: ResonanceSystem = $Resonance
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

## Group names used for world queries.
const GROUP_NIGHTMARE: String = "nightmares"
const GROUP_INTERACTIVE: String = "interactive"
const INTERACT_RADIUS: float = 60.0

var interact_target: Node = null
var pending_resolution: Node = null
var _visual: HunterVisual = null
var _dash_ghost_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	movement.setup(self, hurtbox)
	combat.setup(hitbox, resonance)
	health.setup(self, hurtbox)
	lantern.resonance = resonance
	combat.weapon = NightmareDatabase.default_weapon()
	hurtbox.hit_taken.connect(combat.on_player_hit_taken)
	health.died.connect(_on_died)
	# Movement feel is feedback: every one of these produces something the
	# player sees or hears, which is what makes the movement feel responsive.
	movement.landed.connect(_on_landed)
	movement.jumped.connect(_on_jumped)
	movement.double_jumped.connect(_on_double_jumped)
	movement.dashed.connect(_on_dashed)
	combat.attack_started.connect(_on_attack_started)
	GameManager.nightmare_resolved.connect(_on_nightmare_resolved)
	_build_placeholder_visual()
	_bind_camera()
	WorldManager.enter_region(WorldManager.current_region)


## The camera is a child of the player, so the player hands itself over rather
## than the level having to wire the two together.
func _bind_camera() -> void:
	var camera: Node = get_node_or_null("Camera2D")
	if camera is ShakeCamera:
		(camera as ShakeCamera).bind(self)


func _on_attack_started(kind: int) -> void:
	# Light attacks get a whisper of movement; heavy attacks commit the body.
	if kind in [Hitbox.Kind.HEAVY, Hitbox.Kind.CHARGED]:
		FeedbackManager.shake(2.2, 0.09)
		SlashArc.spawn(self, global_position + Vector2(movement.facing * 20.0, -22.0),
			Vector2(movement.facing, -0.25).normalized(), Palette.BLADE_TRAIL, 46.0)
	else:
		SlashArc.spawn(self, global_position + Vector2(movement.facing * 18.0, -22.0),
			Vector2(movement.facing, -0.35).normalized(), Palette.BLADE_TRAIL, 32.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		movement.request_jump()
	if event.is_action_released(&"jump"):
		movement.release_jump()
	if event.is_action_pressed(&"attack_light"):
		_try_light()
	if event.is_action_pressed(&"attack_heavy"):
		combat.start_heavy_attack()
	if event.is_action_pressed(&"dash"):
		movement.request_dash()
	if event.is_action_pressed(&"lantern"):
		_use_lantern()
	if event.is_action_pressed(&"anchor"):
		_use_anchor()
	if event.is_action_pressed(&"revelation"):
		if resonance.is_ready_for_revelation():
			resonance.start_revelation()
	if event.is_action_pressed(&"interact"):
		_try_interact()
	if event.is_action_pressed(&"special"):
		abilities.activate_special(self, movement)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	_dash_ghost_timer = maxf(0.0, _dash_ghost_timer - delta)
	if _visual != null:
		_visual.dash_ghost(_dash_ghost_timer)
	# Mouse aiming (Settings, default on): the Hunter faces the cursor, which
	# is what the jam requires of a keyboard + mouse game. Falls back cleanly
	# to movement direction when the option is off.
	if Settings.use_mouse_to_aim and _aim_from_mouse():
		combat.set_facing(movement.facing)
	else:
		movement.set_facing(movement.facing)
		combat.set_facing(movement.facing)
	movement.set_airborne(not is_on_floor())
	combat.set_airborne(not is_on_floor())
	_refresh_interactable()
	abilities.tick(delta, self)
	resonance.tick(delta)


## Faces the cursor when the pointer is meaningfully away from the Hunter, so
## a resting mouse in the middle of the screen does not pin the facing.
func _aim_from_mouse() -> bool:
	var camera: Camera2D = get_viewport_camera_2d()
	if camera == null:
		return false
	var pointer: Vector2 = get_global_mouse_position()
	var offset: float = pointer.x - global_position.x
	if absf(offset) < 14.0:
		return false
	movement.facing = 1.0 if offset > 0.0 else -1.0
	return true


func _try_light() -> void:
	if not is_on_floor():
		if combat.start_aerial_attack():
			return
	combat.start_light_attack()


# --- Instruments ------------------------------------------------------------
func _use_lantern() -> void:
	lantern.reveal_from(global_position, _nearby_nightmares() + _nearby_interactables())


func _use_anchor() -> void:
	var candidates: Array[Node] = _nearby_nightmares() + _nearby_interactables()
	anchor.deploy(global_position, candidates)


func _nearby_nightmares() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(GROUP_NIGHTMARE):
		if node is Node2D and is_instance_valid(node):
			out.append(node)
	return out


func _nearby_interactables() -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(GROUP_INTERACTIVE):
		if node is Node2D and is_instance_valid(node):
			out.append(node)
	return out


# --- Interaction / resolution -----------------------------------------------
func _refresh_interactable() -> void:
	var best: Node = null
	var best_distance: float = INTERACT_RADIUS
	for node: Node in _nearby_interactables() + _nearby_nightmares():
		if not node.has_method("can_interact"):
			continue
		if not bool(node.can_interact()):
			continue
		var distance: float = global_position.distance_to((node as Node2D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	if best == interact_target:
		return
	interact_target = best
	if best == null:
		interaction_cleared.emit()
	else:
		interaction_available.emit(best)


func _try_interact() -> void:
	if interact_target == null:
		return
	if not interact_target.has_method("interact_with"):
		return
	interact_target.interact_with(self)


## Called by a nightmare when it offers its resolution (GDD 6, Stage 7).
func offer_resolution(nightmare: Node, options: Array[int]) -> void:
	pending_resolution = nightmare
	resolution_prompt_opened.emit(nightmare, options)


func choose_resolution(resolution: int) -> void:
	if pending_resolution == null:
		return
	if pending_resolution.has_method("resolve"):
		pending_resolution.resolve(resolution)
	pending_resolution = null


func _on_nightmare_resolved(_nightmare_id: StringName, _resolution: int) -> void:
	pending_resolution = null


func _on_died() -> void:
	combat.cancel()
	await get_tree().create_timer(1.1).timeout
	var spawn: Vector2 = health.respawn()
	global_position = spawn
	velocity = Vector2.ZERO
	# Boss progress resets unless an encounter checkpoint says otherwise (GDD 12).
	resonance.reset()


# --- Visuals ----------------------------------------------------------------
## The Hunter is drawn in code by HunterVisual. It reads real gameplay state
## (velocity, facing, swing phase, hurt flash) so the drawing *is* the
## animation, which keeps a web build free of sprite sheets and import cost.
func _build_placeholder_visual() -> void:
	_visual = HunterVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	_visual.bind(self, movement, combat)


## Landing has to be felt, not just observed. A heavy arrival shakes the camera
## a little and kicks up dust; a light one does neither.
func _on_landed(impact_speed: float) -> void:
	if impact_speed < 220.0:
		return
	var strength: float = clampf(impact_speed / 900.0, 0.0, 0.6)
	FeedbackManager.shake(strength * 5.0, 0.14)
	Fx.dust(self, global_position, int(roundf(4.0 + strength * 8.0)))
	AudioManager.play_named(&"land")


func _on_jumped() -> void:
	Fx.dust(self, global_position, 5)


func _on_double_jumped() -> void:
	Fx.burst(self, global_position + Vector2(0, -18.0), Palette.LANTERN, 8)


func _on_dashed(direction: Vector2) -> void:
	Fx.dust(self, global_position, 7)
	FeedbackManager.shake(1.4, 0.07)
	_dash_ghost_timer = 0.4


func hit_react(_strength: float, _point: Vector2) -> void:
	if _visual != null:
		_visual.flash()
