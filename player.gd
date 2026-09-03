extends CharacterBody2D


var SPEED = 120.0
@onready var player_sprite = $AnimatedSprite2D
@onready var walksound: AudioStreamPlayer2D = $walk
@onready var vignette_rect: ColorRect = $DamageUI/Vignette
@onready var healthbar: TextureProgressBar = $uiLayer/TextureProgressBar
const tilt_angle = 5.0
const tilt_speed = 60.0
var STEP_DELAY: float = 0.35
var step_timer: float = 0.0
var direction: Vector2 = Vector2.ZERO
var health = 100.0
@export var ACCELERATION: float = 2000.0  # How fast you speed up
@export var FRICTION: float = 1500.0    # How fast you slide to a stop
var RECOIL_FORCE: float = 80.0   # Speed of the backward jolt (pixels/second)
var RECOIL_FRICTION: float = 10.0 # How fast your player skids to a stop after shooting
var weapon_recoil_velocity: Vector2 = Vector2.ZERO
@export var max_health: float = 100.0
@onready var current_health: float = max_health
var player_is_dead: bool = false
var audio_muffle_tween: Tween = null
var audio_volume_tween: Tween = null # Separate variable tracking to protect properties
var overlay_flash_tween: Tween = null # 🎨 New: Tracks your visual overlay property ticks
@onready var burning = $burning
@onready var burning_sound = $burnings
var can_move: bool = true
var slide_speed: float = 0.0        # 📐 Base force threshold injected into your slides
var slipperiness: float = 0.0

func apply_weapon_kickback(direction_to_mouse: Vector2) -> void:
	# Reverse the vector direction (-direction) to push the player backwards away from the mouse!
	weapon_recoil_velocity = -direction_to_mouse * RECOIL_FORCE
func damage(amount: float) -> void:
	if player_is_dead or globals.is_dead: 
		return
		
	current_health -= amount
	health -= amount
	$damage.pitch_scale = randf_range(0.90, 1.3)
	$damage.play()
	# =========================================================================
	# 🎨 THE PUNCHY RED VIGNETTE SCREEN FLASH (THE OVERLAY JUICE)
	# Whenever you take a hit, we instantly jump the vignette's alpha opacity up 
	# to 0.45, and then smoothly fade it back to 0.0 over a snappy 0.35s window!
	# =========================================================================
	if is_instance_valid(vignette_rect):
		# Kill any active overlay tweens to cleanly interrupt rapid back-to-back hits
		if overlay_flash_tween and overlay_flash_tween.is_valid():
			overlay_flash_tween.kill()
			
		overlay_flash_tween = create_tween()
		overlay_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# 🟥 Step A: INSTANTLY burst the red alpha overlay onto the screen lens viewport
		vignette_rect.self_modulate.a = 0.45
		
		# 🟥 Step B: Smoothly fade the transparency track back down to 0.0 (Invisible)
		overlay_flash_tween.tween_property(vignette_rect, "self_modulate:a", 0.0, 0.35)

	# 🎧 1. THE LOW-PASS FREQUENCY FILTER
	var master_bus_index = AudioServer.get_bus_index("Master")
	var low_pass = AudioServer.get_bus_effect(master_bus_index, 0) as AudioEffectLowPassFilter
	if low_pass:
		if audio_muffle_tween and audio_muffle_tween.is_valid():
			audio_muffle_tween.kill()
		audio_muffle_tween = create_tween()
		audio_muffle_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		low_pass.cutoff_frequency = 400.0
		audio_muffle_tween.tween_property(low_pass, "cutoff_frequency", 20000.0, 0.6)
	
	# 🔊 2. THE CHANNELS METHOD VOLUME OVERLAY
	if audio_volume_tween and audio_volume_tween.is_valid():
		audio_volume_tween.kill()
	audio_volume_tween = create_tween()
	audio_volume_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	AudioServer.set_bus_volume_db(master_bus_index, -12.0)
	audio_volume_tween.tween_method(
		func(volume_val: float): AudioServer.set_bus_volume_db(master_bus_index, volume_val),
		-12.0, 0.0, 0.4
	)
	
	# Your camera screen shake jolt
	var camera_node = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camera_node) and camera_node.has_method("add_shake"):
		camera_node.add_shake(8.0)
	if healthbar:
		# =========================================================================
		# 📈 1. THE SMOOTH PROGRESS SLIDER DRAIN ENGINE
		# Glides the filling bar value smoothly down to your current health.
		# =========================================================================
		var health_drain = create_tween()
		health_drain.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		health_drain.tween_property(healthbar, "value", health, 0.35)

		# =========================================================================
		# 💥 2. THE MULTI-AXIS JUICE MATRIX (SCALE POP, TILT, & BRIGHT FLASH)
		# We force the bar to instantly balloon outward, rock sideways, and flash 
		# solid white simultaneously the exact frame a torch fireball hits!
		# =========================================================================
		if healthbar.pivot_offset == Vector2.ZERO:
			healthbar.pivot_offset = healthbar.size / 2.0
		
		# Cache the original baseline progress bar color so the flash knows its home target!
		# 💡 (If your progress bar color is green inside the Inspector, this catches it automatically)
		var original_bar_tint = healthbar.tint_progress
		
		var bar_juice = create_tween()
		var ta = deg_to_rad(10.0)
		
		# 🚀 STEP A: EXPLOSIVE PARALLEL IMPACT POP & WHITE FLASH (0.05s)
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(healthbar, "rotation", ta, 0.05)
		bar_juice.tween_property(healthbar, "scale", Vector2(1.3, 1.3), 0.05)
		
		# ⚡ FORCE SOLID WHITE FLASH TINT: We force all color channels to pure maximum brightness!
		bar_juice.tween_property(healthbar, "tint_progress", Color(0.843, 0.483, 0.487, 1.0), 0.05)
		
		# 🔄 STEP B: THE DECAYING SEQUENCE CHAIN & COLOR RECOVERY
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(healthbar, "rotation", -ta, 0.05)
		
		# Begin returning the color blend back to normal while the bar continues rocking left/right
		bar_juice.set_parallel(true)
		bar_juice.tween_property(healthbar, "rotation", ta * 0.5, 0.05)
		bar_juice.tween_property(healthbar, "scale", Vector2(1.1, 1.1), 0.05)
		
		# Smoothly blend the white tint halfway back to its original native health bar color mapping
		var mid_tint = original_bar_tint.lerp(Color.WHITE, 0.4)
		bar_juice.tween_property(healthbar, "tint_progress", mid_tint, 0.05)
		
		bar_juice.chain().set_parallel(false)
		bar_juice.tween_property(healthbar, "rotation", -ta * 0.3, 0.05)
		
		# Final absolute snap back to flat 0.0 rotation, standard 1.0 scale, and clean native tint color
		bar_juice.chain().set_parallel(true)
		bar_juice.tween_property(healthbar, "rotation", 0.0, 0.05)
		bar_juice.tween_property(healthbar, "scale", Vector2.ONE, 0.05)
		bar_juice.tween_property(healthbar, "tint_progress", original_bar_tint, 0.15)
	if current_health <= 0.0:
		trigger_player_death()
func trigger_player_death() -> void:
	player_is_dead = true
	globals.is_dead = true
	if healthbar:
		healthbar.visible = false
	# Disable the player's controls and movement axes
	velocity = Vector2.ZERO
	set_physics_process(false) # Freezes the player script
	queue_free()
	
	# Play player death animation or load a Game Over screen overlay
	# Example: get_tree().change_scene_to_file("res://ui/game_over_screen.tscn")
func _ready() -> void:
	globals.player = self
	if healthbar:
		healthbar.max_value = health
		healthbar.value = health
	health = max_health
	if audio_muffle_tween != null:
		audio_muffle_tween.kill()
	globals.is_dead = false
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, 0.0)
func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	controls()
	
	weapon_recoil_velocity = weapon_recoil_velocity.move_toward(Vector2.ZERO, RECOIL_FRICTION * RECOIL_FORCE * delta)
	
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	# =========================================================================
	# 📈 STANDARD ACCELERATION, MOMENTUM & INVERSE FRICTION PIPELINE
	# 💡 FIXED: Dynamically alters your player's default top speeds and friction!
	# If slipperiness is 0.0, you stop on a dime. If upgraded, you slide smoothly!
	# =========================================================================
	if input_dir != Vector2.ZERO:
		# 💡 FIXED: Your top walking speed dynamically scales up if your slide card adds speed!
		var target_velocity = input_dir * (SPEED + slide_speed)
		
		velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
		velocity.y = move_toward(velocity.y, target_velocity.y, ACCELERATION * delta)
	else:
		# 💡 FIXED: Computes your inverse friction decay using your dedicated slipperiness value!
		var calibrated_friction_decay = FRICTION / (1.0 + slipperiness * 8.0)
		
		velocity.x = move_toward(velocity.x, 0.0, calibrated_friction_decay * delta)
		velocity.y = move_toward(velocity.y, 0.0, calibrated_friction_decay * delta)

	# Integrate weapon recoil packs cleanly
	var final_movement_velocity = velocity + weapon_recoil_velocity
	
	var old_velocity = velocity 
	velocity = final_movement_velocity
	move_and_slide()
	velocity = old_velocity 
	
	apply_tilt(delta)
	handle_footsteps(delta)
func controls():
	player_sprite.flip_h = get_local_mouse_position().x < 0.0
	direction = Input.get_vector("left", "right", "up", "down")
	if direction == Vector2.ZERO:
		player_sprite.play("idle_right")
		return
	if abs(direction.x) >= abs(direction.y):
		if direction.x > 0:
			player_sprite.play("move_side")
		else:
			player_sprite.play("move_side")
	else:
		if direction.y > 0:
			player_sprite.play("move_side")
		else:
			player_sprite.play("move_side")
func apply_tilt(delta: float) -> void:
	var target_rotation = 0.0
	
	# Check if the player is actually pressing movement keys
	if direction != Vector2.ZERO:
		
		# --- 1. DIAGONAL MOVEMENT STATES ---
		if direction.x > 0 and direction.y < 0:
			# Up and Right -> Tilts LEFT
			target_rotation = -tilt_angle 
		elif direction.x < 0 and direction.y < 0:
			# Up and Left -> Tilts RIGHT
			target_rotation = tilt_angle
		elif direction.x > 0 and direction.y > 0:
			# Down and Right -> Tilts RIGHT
			target_rotation = tilt_angle
		elif direction.x < 0 and direction.y > 0:
			# Down and Left -> Tilts LEFT
			target_rotation = -tilt_angle
			
		# --- 2. STRAIGHT MOVEMENT STATES ---
		elif direction.x > 0:
			# Straight Right
			target_rotation = tilt_angle
		elif direction.x < 0:
			# Straight Left
			target_rotation = -tilt_angle
		elif direction.y < 0:
			# Straight Up (Optional: Add a slight tilt if you want)
			target_rotation = -tilt_angle * 0.5 
		elif direction.y > 0:
			# Straight Down (Optional: Add a slight tilt if you want)
			target_rotation = tilt_angle * 0.5

	# Smoothly blend the current rotation to the target rotation
	rotation_degrees = move_toward(rotation_degrees, target_rotation, tilt_speed * delta)
func handle_footsteps(delta: float) -> void:
	# 4. Only tick the timer if the player is actively pressing keys and moving
	if direction != Vector2.ZERO and velocity.length() > 50.0:
		step_timer -= delta
		
		# If the countdown hits zero, it's time to take a step!
		if step_timer <= 0.0:
			play_footstep_sound()
			step_timer = STEP_DELAY # Reset the stride gatekeeper
	else:
		# If the player stands still, instantly reset the timer 
		# so the very next step they take plays immediately!
		step_timer = 0.0
func play_footstep_sound() -> void:
	if walksound:
		# 5. Juicing the audio: Randomize the pitch and volume slightly per step!
		# This breaks up the repetitive machine-gun loop effect and sounds completely organic.
		walksound.pitch_scale = randf_range(0.88, 1.12)
		walksound.volume_db = randf_range(0.2, 0.6)
		walksound.play()
	
