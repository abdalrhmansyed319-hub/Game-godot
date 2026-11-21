class_name PlayerHealth
extends Node
## PlayerHealth — health, damage response, death and respawn (GDD 12).
##
## Death is not a hard reset: story discoveries stay recorded and the player
## returns to the last Quiet Room. Experimentation must stay cheap.

signal took_damage(amount: float, source: Node)
signal died
signal respawned(position: Vector2)

@export var invulnerability_after_hit: float = 0.7
@export var knockback_strength: float = 260.0

var hurtbox: Hurtbox
var body: CharacterBody2D
var is_dead: bool = false
var _unbanked_fragments: int = 0


func setup(owner_body: CharacterBody2D, owner_hurtbox: Hurtbox) -> void:
	body = owner_body
	hurtbox = owner_hurtbox
	hurtbox.hit_taken.connect(_on_hit_taken)
	GameManager.player_died.connect(_on_player_died)


func _on_hit_taken(result: Dictionary) -> void:
	if is_dead:
		return
	var amount: float = float(result.get("damage", 0.0))
	# Resolve reduces distortion-sourced damage (GDD 9, 14).
	if result.get("kind", Hitbox.Kind.LIGHT) == Hitbox.Kind.HAZARD:
		amount *= 1.0 - ProgressionManager.distortion_resistance()
	took_damage.emit(amount, result.get("source", null))
	_apply_knockback(result)
	if hurtbox != null:
		hurtbox.grant_invulnerability(invulnerability_after_hit)


func _apply_knockback(result: Dictionary) -> void:
	if body == null:
		return
	var source: Variant = result.get("source", null)
	var direction: float = 1.0
	if source is Node2D and body != null:
		direction = signf(body.global_position.x - (source as Node2D).global_position.x)
		if is_zero_approx(direction):
			direction = -1.0
	body.velocity.x = direction * knockback_strength
	body.velocity.y = -knockback_strength * 0.35


func _on_player_died() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_named(&"death")
	died.emit()


## Death handling per GDD 12: return to checkpoint, keep discoveries,
## drop recoverable resources.
func respawn() -> Vector2:
	is_dead = false
	var spawn: Vector2 = WorldManager.respawn_position()
	GameManager.health = GameManager.max_health
	GameManager.health_changed.emit(GameManager.health, GameManager.max_health)
	# Some unbanked resources stay recoverable in the world.
	_unbanked_fragments = int(float(GameManager.dream_fragments) * 0.4)
	GameManager.add_fragments(-_unbanked_fragments)
	if body != null:
		body.global_position = spawn
		body.velocity = Vector2.ZERO
	respawned.emit(spawn)
	return spawn


func recoverable_fragments() -> int:
	return _unbanked_fragments


func clear_recoverable() -> void:
	_unbanked_fragments = 0
