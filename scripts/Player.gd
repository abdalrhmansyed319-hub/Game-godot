extends Node2D

# Chronoflora - Player (The Keeper)
# Handles movement and animation for the player character.

var speed = 120.0
var direction = "down"
var frame = 0
var frame_timer = 0.0
var moving = false

# Sprite sheet is arranged as 4 rows (directions) x 4 columns (frames)
# Row 0: down, Row 1: up, Row 2: left, Row 3: right
const FRAMES_PER_DIRECTION = 4
const FRAME_WIDTH = 16
const FRAME_HEIGHT = 24
const DIRECTION_ROWS = {
	"down": 0,
	"up": 1,
	"left": 2,
	"right": 3,
}

var sprite_sheet: Texture2D

func _ready():
	sprite_sheet = load("res://assets/images/player/keeper.png")

func _process(delta):
	# Read input and move
	var dx = 0.0
	var dy = 0.0
	
	if Input.is_action_pressed("ui_left"):
		dx = -1.0
	if Input.is_action_pressed("ui_right"):
		dx = 1.0
	if Input.is_action_pressed("ui_up"):
		dy = -1.0
	if Input.is_action_pressed("ui_down"):
		dy = 1.0
	
	move(dx, dy, delta)
	
	# Update animation frame
	if moving:
		frame_timer += delta
		if frame_timer > 0.12:
			frame_timer = 0
			frame = (frame + 1) % FRAMES_PER_DIRECTION
	else:
		frame = 0

func _draw():
	if not sprite_sheet:
		return
	
	var row = DIRECTION_ROWS.get(direction, 0)
	var src_rect = Rect2(
		frame * FRAME_WIDTH,
		row * FRAME_HEIGHT,
		FRAME_WIDTH,
		FRAME_HEIGHT
	)
	
	var dest_rect = Rect2(
		-8, -12,  # Center the sprite on the node position
		32, 48    # Display size (2x)
	)
	
	draw_texture_rect(sprite_sheet, dest_rect, false, src_rect, Color(1, 1, 1, 1))

func move(dx, dy, delta):
	"""Move the player and update direction."""
	global_position += Vector2(dx, dy) * speed * delta
	
	if abs(dx) > abs(dy):
		direction = "right" if dx > 0 else "left"
	elif abs(dy) > abs(dx):
		direction = "down" if dy > 0 else "up"
	
	moving = (dx != 0 or dy != 0)

func stop():
	moving = false

func get_world_position():
	return global_position
