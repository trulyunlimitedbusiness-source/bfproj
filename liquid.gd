extends CharacterBody2D

# 🔗 REQUIRED NODES
@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavAgent
@onready var damage_audio: AudioStreamPlayer2D = $damage
@onready var shadow: Sprite2D = $Sprite2D
@onready var ehb: TextureProgressBar = $enemyhealth

# 🎛️ CORE CONSTANTS & VARIABLES
@export var speed: float = 90.0
@export var max_health: float = 100.0
var health: float = max_health
var direction: Vector2 = Vector2.ZERO
var hit_bounce_tween: Tween = null

enum state {attack, move}
const ATTACK_RANGE: float = 14.0
const attack_tick_rate: float = 0.75
var current_state: state = state.move
var attack_timer: float = 0.0
const DAMAGE_FONT = preload("res://ui/fonts/Pixel Digivolve.otf")
var is_dead: bool = false

# 🧠 FLOCKING & VARIATION (FIXES ROBOTIC MOVEMENT)
var target_offset: Vector2 = Vector2.ZERO
var path_update_timer: float = 0.0
var path_update_interval: float = 0.2
var actual_speed: float = 90.0

# 💥 COMBAT FEEL SETTINGS (KNOCKBACK & HIT-STOP)
const KNOCKBACK_FORCE: float = 10.0
const KNOCKBACK_FRICTION: float = 5.0
const HIT_STOP_DURATION: float = 0.1
var knockback_velocity: Vector2 = Vector2.ZERO
var is_frozen: bool = false
var pre_squish_scale: Vector2 = Vector2.ONE
var dmga: bool = false

# 🎨 SHADER WHITE-PINK FLASH REGISTERS
var is_flashing: bool = false
var flash_timer: float = 0.0
const FLASH_DURATION: float = 0.08

func _ready() -> void:
	if ehb:
		ehb.max_value = health
		ehb.value = health
	if is_instance_valid(body_sprite) and body_sprite.material:
		body_sprite.material = body_sprite.material.duplicate()
	health = max_health
	add_to_group("enemies")
	
	# 1. Scale Variance
	var random_multiplier: float = randf_range(0.9, 1.1)
	scale = Vector2(random_multiplier, random_multiplier)
	pre_squish_scale = scale

	# 2. Speed Variance (Enemies walk at slightly different speeds)
	actual_speed = speed * randf_range(0.85, 1.15)

	# 3. Target Offset (Each enemy aims for a different spot around the player)
	target_offset = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))

	# 4. Path Update Stagger (Prevents all enemies from updating paths on the exact same frame)
	path_update_interval = randf_range(0.15, 0.35)

	# 🧭 Connect Avoidance
	if is_instance_valid(nav_agent):
		nav_agent.velocity_computed.connect(_on_nav_agent_velocity_computed)

func _physics_process(delta: float) -> void:
	if is_dead: 
		return
		
	# 📡 A. SHADER DAMAGE TIMELINE TICK DOWN
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			if is_instance_valid(body_sprite) and body_sprite.material:
				body_sprite.material.set_shader_parameter("flash_modifier", 0.0)
				
	# 📡 B. SECURITY HOOK
	if globals.player == null:
		globals.player = get_tree().current_scene.find_child("player", true, false) as CharacterBody2D
		return
		
	if is_instance_valid(body_sprite) and abs(velocity.x) > 0.1:
		body_sprite.flip_h = velocity.x < 0.0
		
	# 🛑 HIT-STOP FREEZE GATE
	if is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var distance_to_player: float = global_position.distance_to(globals.player.global_position)
	
	# 🧠 C. STATE MACHINE
	if distance_to_player <= ATTACK_RANGE:
		current_state = state.attack
	else:
		current_state = state.move
		
	match current_state:
		state.move:
			attack_timer = 0.0
			if body_sprite and body_sprite.animation != "walk":
				body_sprite.play("walk")

			# 🎲 PATH RECALCULATION TIMING (Staggered updates to reduce CPU strain & create natural curves)
			path_update_timer -= delta
			if path_update_timer <= 0.0:
				path_update_timer = path_update_interval
				
				# If close to player, collapse the offset so they close in for the attack
				var current_offset = target_offset if distance_to_player > 60.0 else Vector2.ZERO
				nav_agent.target_position = globals.player.global_position + current_offset

			direction = global_position.direction_to(nav_agent.get_next_path_position())
			
			if nav_agent.is_target_reached() == false:
				var desired_velocity = direction * actual_speed
				if nav_agent.avoidance_enabled:
					nav_agent.set_velocity(desired_velocity)
				else:
					_apply_movement(desired_velocity, delta)
				
		state.attack:
			if body_sprite and body_sprite.animation != "attack":
				body_sprite.play("attack")
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * actual_speed * 10.0 * delta)
			velocity = knockback_velocity
			move_and_slide()
			
			attack_timer -= delta
			if attack_timer <= 0.0:
				strike_player()
				attack_timer = attack_tick_rate

# 🧭 AVOIDANCE CALLBACK FUNCTION
func _on_nav_agent_velocity_computed(safe_velocity: Vector2) -> void:
	var delta = get_physics_process_delta_time()
	_apply_movement(safe_velocity, delta)

func _apply_movement(target_velocity: Vector2, delta: float) -> void:
	var chase_velocity = velocity.lerp(target_velocity, delta * 10.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * actual_speed * delta)
	velocity = chase_velocity + knockback_velocity
	move_and_slide()

func strike_player() -> void:
	if globals.player_can_be_damaged and globals.player and globals.player.has_method("damage"):
		globals.player_can_be_damaged = false
		globals.player.damage(20.0)
		get_tree().create_timer(attack_tick_rate).timeout.connect(func():
			globals.player_can_be_damaged = true
		)

func take_damage(amount: float, bullet_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead: 
		return
		
	var camera = get_tree().get_first_node_in_group("camera")
	health -= amount
	damage_number(amount, global_position)
	is_flashing = true
	flash_timer = FLASH_DURATION
	
	if is_instance_valid(body_sprite) and body_sprite.material:
		body_sprite.material.set_shader_parameter("flash_modifier", 1.0)
		
	if damage_audio:
		damage_audio.pitch_scale = randf_range(0.88, 1.12)
		damage_audio.volume_db = randf_range(-2.8, -0.8)
		damage_audio.play()
		
	if ehb:
		ehb.value = health
		
	var original_bar_x = ehb.position.x
	var bar_shake = create_tween()
	bar_shake.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	bar_shake.tween_property(ehb, "position:x", original_bar_x + 5.0, 0.05)
	bar_shake.chain().tween_property(ehb, "position:x", original_bar_x - 5.0, 0.05)
	bar_shake.chain().tween_property(ehb, "position:x", original_bar_x + 3.0, 0.05)
	bar_shake.chain().tween_property(ehb, "position:x", original_bar_x - 3.0, 0.05)
	bar_shake.chain().tween_property(ehb, "position:x", original_bar_x, 0.05)
	
	if health <= 0.0:
		trigger_clean_death()
	else:
		trigger_hit_stop()
		
	if bullet_direction != Vector2.ZERO:
		knockback_velocity = bullet_direction * KNOCKBACK_FORCE
	else:
		var live_player = globals.player
		if is_instance_valid(live_player):
			var push_direction = live_player.global_position.direction_to(global_position).normalized()
			knockback_velocity = push_direction * KNOCKBACK_FORCE
			
	if camera and camera.has_method("add_shake"):
		camera.add_shake(2.5)
		
	const SHRINK_RATE: float = 0.48  
	const MAX_SCALE_CEILING: float = 1.0
	const MIN_SCALE_FLOOR: float = 0.3

	var base_damage_taken = 100.0 - health
	var total_shrink_applied = (base_damage_taken / 100.0) * SHRINK_RATE

	var current_scale_target = 1.0 - total_shrink_applied
	var health_percent: float = clamp(current_scale_target, MIN_SCALE_FLOOR, MAX_SCALE_CEILING)
	var true_target_resting_scale = Vector2(health_percent, health_percent)

	if hit_bounce_tween and hit_bounce_tween.is_valid():
		hit_bounce_tween.kill()
	
	hit_bounce_tween = create_tween()

	var squish_out = Vector2(true_target_resting_scale.x + 0.40, true_target_resting_scale.y - 0.40)
	var stretch_up = Vector2(true_target_resting_scale.x - 0.15, true_target_resting_scale.y + 0.20)

	hit_bounce_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_bounce_tween.tween_property(self, "scale", squish_out, 0.05)

	hit_bounce_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hit_bounce_tween.tween_property(self, "scale", stretch_up, 0.06)

	hit_bounce_tween.tween_property(self, "scale", true_target_resting_scale, 0.10)

func trigger_hit_stop() -> void:
	is_frozen = true
	await get_tree().create_timer(HIT_STOP_DURATION).timeout
	is_frozen = false

func trigger_clean_death() -> void:
	if is_dead: 
		return
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	
	if has_node("GPUParticles2D"):
		get_node("GPUParticles2D").emitting = true
		
	if ehb: 
		ehb.visible = false
		
	if is_instance_valid(body_sprite):
		if body_sprite.material:
			body_sprite.material.set_shader_parameter("flash_modifier", 0.0)
		if body_sprite.sprite_frames.has_animation("puddle"):
			body_sprite.stop()
			body_sprite.play("puddle")
			var frames_count = body_sprite.sprite_frames.get_frame_count("puddle")
			var animation_fps = body_sprite.sprite_frames.get_animation_speed("puddle")
			var total_puddle_duration = float(frames_count) / float(animation_fps)
			
			var cleanup_tween = create_tween()
			cleanup_tween.tween_interval(total_puddle_duration)
			cleanup_tween.tween_callback(queue_free)
		else:
			queue_free()
	else:
		queue_free()
		
	if has_node("death"):
		$death.play()

func damage_number(damage_amount: float, target_global_pos: Vector2) -> void:
	if dmga: 
		return
	dmga = true
	
	var pop_text = Label.new()
	pop_text.text = str(int(damage_amount))
	pop_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pop_text.add_theme_font_override("font", DAMAGE_FONT)
	pop_text.add_theme_color_override("font_outline_color", Color(0.636, 0.128, 0.128, 1.0))
	pop_text.add_theme_constant_override("outline_size", 6)
	pop_text.scale = Vector2(0.5, 0.5)
	pop_text.modulate = Color(1.0, 0.685, 0.664, 1.0)
	
	get_tree().current_scene.add_child(pop_text)
	pop_text.reset_size()
	pop_text.position = target_global_pos - Vector2(pop_text.size.x / 2.0, 24)
	
	var upward_target_y = pop_text.position.y - randf_range(4.0, 10.0)
	var pop_tween = create_tween().set_parallel(true)
	pop_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(pop_text, "position:y", upward_target_y, 0.46)
	pop_tween.tween_property(pop_text, "modulate:a", 0.0, 0.42)
	
	pop_tween.chain().tween_callback(func():
		if is_instance_valid(pop_text):
			pop_text.queue_free()
		dmga = false
	)
