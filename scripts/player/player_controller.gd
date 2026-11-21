class_name PlayerController
extends CharacterBody2D
## PlayerController — the Hunter (GDD 3, 4, 5).
##
## Owns input routing and the visual placeholder. All feel lives in
## PlayerMovement, all combat in PlayerCombat, all instruments in their own
## nodes, so each system can be tuned independently.

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
var _visual_root: Node2D = null


func _ready() -> void:
	add_to_group("player")
	movement.setup(self, hurtbox)
	combat.setup(hitbox, resonance)
	health.setup(self, hurtbox)
	lantern.resonance = resonance
	combat.weapon = NightmareDatabase.default_weapon()
	hurtbox.hit_taken.connect(combat.on_player_hit_taken)
	health.died.connect(_on_died)
	GameManager.nightmare_resolved.connect(_on_nightmare_resolved)
	_build_placeholder_visual()
	WorldManager.enter_region(WorldManager.current_region)


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


func _physics_process(_delta: float) -> void:
	if health.is_dead:
		return
	movement.set_facing(movement.facing)
	movement.set_airborne(not is_on_floor())
	combat.set_facing(movement.facing)
	combat.set_airborne(not is_on_floor())
	_scale_flip()
	_refresh_interactable()
	abilities.tick(_delta, self)
	resonance.tick(_delta)


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


# --- Placeholder visuals ----------------------------------------------------
## Draws the Hunter with engine primitives so the prototype needs no art.
## Swap `_visual_root` for an AnimatedSprite2D when 02 - Art & Assets lands.
func _build_placeholder_visual() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	var cloak := ColorRect.new()
	cloak.color = Color(0.16, 0.14, 0.24)
	cloak.size = Vector2(18, 30)
	cloak.position = Vector2(-9, -22)
	_visual_root.add_child(cloak)

	var hood := ColorRect.new()
	hood.color = Color(0.28, 0.24, 0.42)
	hood.size = Vector2(14, 12)
	hood.position = Vector2(-7, -32)
	_visual_root.add_child(hood)

	var lamp := ColorRect.new()
	lamp.color = Color(0.98, 0.86, 0.45)
	lamp.size = Vector2(5, 7)
	lamp.position = Vector2(9, -14)
	_visual_root.add_child(lamp)


func _scale_flip() -> void:
	if _visual_root == null:
		return
	var target: float = movement.facing
	if _visual_root.scale.x < 0.0 and target > 0.0:
		_visual_root.scale.x = 1.0
	elif _visual_root.scale.x > 0.0 and target < 0.0:
		_visual_root.scale.x = -1.0
