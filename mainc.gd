extends Camera2D

# 🎮 CHUNKY CAMERA SLIDERS (Adjust directly in the Inspector sidebar panel!)
@export var player: Node2D

@export_group("Glitch Shake")
@export var GLITCH_CHANCE: float = 0.35      
@export var FRAME_STACCATO_SKIP: float = 0.15 
@export var RADICAL_SPIKE_MULT: float = 1.6  

@export_group("Horizon Tilt")
@export var MOVEMENT_TILT_AMOUNT: float = 0.05 
@export var TILT_SPEED: float = 8.0            

@export_group("Gun Zoom Kickback")
@export var BASE_ZOOM_LEVEL: float = 4.5     # 🔍 Your normal, default camera zoom level
@export var KICKBACK_ZOOM_BUMP: float = 0.25 # 💥 How hard the camera snaps inward when firing (e.g. 0.15 means zoom becomes 1.15)
@export var ZOOM_RECOVERY_SPEED: float = 12.0 # 🔄 How fast the camera glides back to normal view (higher is snappier)

# Internal processing state variables
var shake_intensity: float = 0.0
var shake_decay: float = 15.0
var max_rotation: float = 0.15
const SMOOTH_WEIGHT: float = 20.0

var last_glitch_offset: Vector2 = Vector2.ZERO
var last_glitch_rotation: float = 0.0
var target_tilt_angle: float = 0.0

func _ready() -> void:
	add_to_group("camera")

func _process(delta: float) -> void:
	globals.camera = self
	if player == null:
		return
		
	# 1. Smoothly track the player node's global pixel coordinates
	var target_position = player.global_position
	global_position = global_position.lerp(target_position, SMOOTH_WEIGHT * delta)
	
	# =========================================================================
	# 🔍 THE ECHOES OF RED ZOOM KICKBACK ENGINE
	# Every frame, the camera smoothly glides its zoom vector back to your baseline.
	# Because we snap it inward instantly inside add_shake(), this lerp creates 
	# a snappy bounce effect automatically with 0% clutter!
	# =========================================================================
	var current_target_zoom = Vector2(BASE_ZOOM_LEVEL, BASE_ZOOM_LEVEL)
	zoom = zoom.lerp(current_target_zoom, ZOOM_RECOVERY_SPEED * delta)
	
	# 2. Handle directional runner horizon tilt math
	if "velocity" in player and player.velocity.length() > 0.0:
		target_tilt_angle = sign(player.velocity.x) * MOVEMENT_TILT_AMOUNT
	else:
		target_tilt_angle = 0.0
	
	# 3. Chaotic Glitch and Shake Processing Matrix
	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		
		if randf() < FRAME_STACCATO_SKIP and last_glitch_offset != Vector2.ZERO:
			offset = last_glitch_offset
			rotation = lerp(rotation, target_tilt_angle + last_glitch_rotation, TILT_SPEED * delta)
			return 
			
		var noise_rotation: float = 0.0
		if randf() < GLITCH_CHANCE:
			if randf() < 0.5:
				offset.x = randf_range(-shake_intensity, shake_intensity) * RADICAL_SPIKE_MULT
				offset.y = randf_range(-shake_intensity, shake_intensity) * 0.2
			else:
				offset.x = randf_range(-shake_intensity, shake_intensity) * 0.2
				offset.y = randf_range(-shake_intensity, shake_intensity) * RADICAL_SPIKE_MULT
			noise_rotation = randf_range(-max_rotation, max_rotation) * (shake_intensity / 5.0)
		else:
			offset.x = randf_range(-shake_intensity, shake_intensity)
			offset.y = randf_range(-shake_intensity, shake_intensity)
			noise_rotation = randf_range(-max_rotation, max_rotation) * (shake_intensity / 10.0)
			
		rotation = lerp(rotation, target_tilt_angle + noise_rotation, TILT_SPEED * delta)
		last_glitch_offset = offset
		last_glitch_rotation = noise_rotation
	else:
		offset = Vector2.ZERO
		rotation = lerp(rotation, target_tilt_angle, TILT_SPEED * delta)
		last_glitch_offset = Vector2.ZERO
		last_glitch_rotation = 0.0


# 💥 THE IGNITION TRIGGER: Call this function from your torch/gun script on fire!
func add_shake(amount: float) -> void:
	shake_intensity = amount
	target_tilt_angle += randf_range(-max_rotation * 1.5, max_rotation * 1.5)
	
	# =========================================================================
	# 💥 THE ZOOM IMPACT SNAP
	# The exact frame a bullet fires, we explosively multiply the camera's zoom 
	# inward. This creates an immediate visual jolt on screen!
	# =========================================================================
	var extreme_zoom = BASE_ZOOM_LEVEL + KICKBACK_ZOOM_BUMP
	zoom = Vector2(extreme_zoom, extreme_zoom)
