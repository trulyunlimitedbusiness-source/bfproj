extends Node2D

@export var camera: Camera2D
@onready var torch_sprite: AnimatedSprite2D = $torchs
@onready var muzzle: Node2D = $muzzle
var has_billed_heat_this_swipe: bool = false # 🔒 Prevents duplicate heat billing frames
var is_overheat_locked: bool = false # 🔒 True = Ventilation broken, heat is permanent!
var SWIPE_TRAIL_SCENE = preload("res://torch/melee.tscn")

@export_group("Overheat Metrics")
@export var MAX_OVERHEAT: float = 100.0
@export var OVERHEAT_DAMAGE_TICK_RATE: float = 0.6 # ⏱️ How fast you take damage when overheated (0.4s)
@export var OVERHEAT_SELF_DAMAGE: float = 6.0      # 🩸 Damage dealt to player per tick when overheated
@export var COOL_DOWN_DELAY_WINDOW: float = 2.3    # ⏱️ How long you must wait after attacking before cooling starts
@export var COOL_DOWN_SPEED: float = 4.3          # ❄️ How many heat points dissipate per second

#Projectile Values
@export var speed: float = 175.0
@export var damage: float = 25.0
@export var max_range: float = 210.0

# Active real-time tracking registers
var current_overheat_value: float = 0.0
var cooldown_delay_timer: float = 0.0
var overheat_damage_clock: float = 0.0
var overheat_cost = 2.0
var fuel_cost = 1.5

@export var SPREAD = 5.0 
@export var BARREL_LENGTH_PIXELS: float = 24.0
@export var fire_cooldown: float = 0.0
@export var fire_rate: float = 0.40
@export var SLAM_ANGLE_DEGREES: float = 50.0
@export var WAVE_SPEED: float = 10.0
@export var ANGLE_STRENGTH: float = 8.0
@export var SQUASH_STRENGTH: float = 0.12
@onready var burning = $UiLayer/overheat/burning
var is_burning = false
var can_shoot = true

# Visual animation phase ratios
const SWING_RATIO: float = 0.20
const FREEZE_RATIO: float = 0.62
const RECOVERY_RATIO: float = 0.22

# Combat State Process Variables
var attack_life_timer: float = 0.0
var is_attacking: bool = false
var strike_multiplier: float = 1.0
var active_attack_duration: float = 0.0
var time_passed: float = 0.0
@export var swing_speed_ratio: float = 0.45 # Takes exactly 45% of your fire_rate windows
@export var accuracy_spread_degrees: float = 6.5
@onready var melee_zone = $MeleeZone

# =========================================================================
# 🖱️ KINETIC MOUSE SWIPE CONFIGURATORS
# =========================================================================
@export_group("Kinetic Mouse Swipe")
@export var SWIPE_VELOCITY_THRESHOLD: float = 1200.0 # ⚡ Pixels/Sec required to trigger a slice
@export var SWIPE_DAMAGE: float = 18.0               # Base damage dealt by manual swipe
@export var SWIPE_PARTICLE_BOOST: float = 5.0        # How large the flame swells mid-swipe

@export var MELEE_SWING_RATIO: float = 0.18
@export var MELEE_FREEZE_RATIO: float = 0.55
@export var MELEE_RECOVERY_RATIO: float = 0.20
@export var active_melee_attack_duration: float = 0.45

var is_melee_attacking: bool = false
var melee_attack_life_timer: float = 0.0

# 🔍 FIXED CAMERA ZOOM CONSTANTS
@export var UNZOOMED_BASE_LEVEL: float = 4.5    
@export var MELEE_CAMERA_ZOOM_IN: float = 5.25   
@export var MELEE_ZOOM_SPEED: float = 8.0        

# Mouse motion and weapon cooldown calculation buffers
var last_mouse_position: Vector2 = Vector2.ZERO
var current_swipe_speed: float = 0.0
var is_swiping_active: bool = false
var melee_cooldown: float = 0.0 # 🔒 Prevents gesture spamming past your fire rate limit!
@onready var overheat: TextureProgressBar = $UiLayer/overheat
var max_overheat = 100.0
var min_overheat = 0.0
var max_fuel = 100.0
var min_fuel = 0.0
var current_overheat = 0.0
var current_fuel = 0.0
@onready var fuel_bar: TextureProgressBar = $UiLayer/fuel
var has_played_oof = false
var shoot_count = 1
var projectile_size: Vector2 = Vector2(1.0, 1.0)

# Tracks what specific enemies are currently inside our hitboxes
var enemies_currently_overlapping: Array[CharacterBody2D] = []

const projectile_scene = preload("res://torch/projectiles/projectile.tscn")

func _ready() -> void:
	fuel_bar.value = max_fuel
	current_fuel = fuel_bar.value
	is_burning = false
	globals.torch = self
	overheat.value = min_overheat
	last_mouse_position = get_global_mouse_position()
	$ash.emitting = false

func _process(delta: float) -> void:
	if is_instance_valid(globals.player) and "can_shoot" in globals.player:
		if not globals.player.can_shoot: 
			is_melee_attacking = false
			is_attacking = false
			return

	# =========================================================================
	# ⛽ SYSTEM 1: OUT OF FUEL AUTOMATIC SAFETY LOCKDOWN
	# =========================================================================
	if current_fuel <= 0.0:
		if torch_sprite and torch_sprite.animation != "ashed":
			torch_sprite.play("ashed")
			
		if is_swiping_active:
			is_swiping_active = false
			
		if is_instance_valid(camera) and "BASE_ZOOM_LEVEL" in camera:
			camera.BASE_ZOOM_LEVEL = lerp(camera.BASE_ZOOM_LEVEL, UNZOOMED_BASE_LEVEL, MELEE_ZOOM_SPEED * delta)
			
		if has_node("../DamageUI/CinematicVignette"):
			var dark_vignette = get_node("../DamageUI/CinematicVignette") as ColorRect
			if is_instance_valid(dark_vignette) and dark_vignette.material:
				var current_alpha = dark_vignette.material.get_shader_parameter("alpha_multiplier")
				dark_vignette.material.set_shader_parameter("alpha_multiplier", lerp(current_alpha, 0.0, MELEE_ZOOM_SPEED * delta))
				
		$FlameParticles.process_material.color = Color(0.192, 0.058, 0.06, 1.0)
		$light.visible = false
		
		_execute_math_mouse_aim(0.0)
		
		if !has_played_oof:
			if has_node("out of fuel"):
				$"out of fuel".play()
			$ash.emitting = true
			has_played_oof = true
		return 
	else:
		$FlameParticles.process_material.color = Color(1.0, 1.0, 1.0, 1.0)
		$light.visible = true

	# =========================================================================
	# 🎛️ SYSTEM 2: VENTILATION OVERHEAT AND PROGRESS JITTER CORES
	# =========================================================================
	if current_overheat_value >= 80.0:
		is_overheat_locked = true
		
	if is_overheat_locked:
		cooldown_delay_timer = COOL_DOWN_DELAY_WINDOW
	elif cooldown_delay_timer > 0.0:
		cooldown_delay_timer -= delta
	else:
		current_overheat_value = move_toward(current_overheat_value, 0.0, COOL_DOWN_SPEED * delta)
		
	if is_instance_valid(overheat):
		overheat.value = current_overheat_value
		if current_overheat_value >= MAX_OVERHEAT:
			if overheat.pivot_offset == Vector2.ZERO:
				overheat.pivot_offset = overheat.size / 2.0
			var panic_wave_offset = sin(time_passed * 28.0) * 8.0
			overheat.position.x = panic_wave_offset
			var panic_tilt_angle = sin(time_passed * 22.0) * deg_to_rad(8.0)
			overheat.rotation = panic_tilt_angle
		else:
			overheat.position.x = 15.0
			overheat.rotation = 0.0

	# =========================================================================
	# 🩸 SYSTEM 3: SELF-DAMAGE OVERLOAD DECAY TICKS
	# =========================================================================
	if current_overheat_value >= MAX_OVERHEAT:
		overheat_damage_clock -= delta
		if overheat_damage_clock <= 0.0:
			var active_player = globals.player if "player" in globals else null
			if is_instance_valid(active_player) and active_player.has_method("damage"):
				burning.emitting = true
				active_player.damage(OVERHEAT_SELF_DAMAGE)
				active_player.burning.emitting = true
				if is_burning == false:
					active_player.burning_sound.play()
					is_burning = true
				if camera and camera.has_method("add_shake"):
					camera.add_shake(6.0)
				overheat_damage_clock = OVERHEAT_DAMAGE_TICK_RATE
	else:
		if is_instance_valid(burning): burning.emitting = false
		if is_instance_valid(globals.player) and "burning" in globals.player:
			if is_instance_valid(globals.player.burning): globals.player.burning.emitting = false
			if is_instance_valid(globals.player.burning_sound): globals.player.burning_sound.stop()
		is_burning = false
		overheat_damage_clock = 0.0
		
	time_passed += delta
	
	# Tick down both of your combat cooldown clocks safely via delta
	if fire_cooldown > 0.0: fire_cooldown -= delta
	if melee_cooldown > 0.0: melee_cooldown -= delta
	
	# Real-time velocity tracking calculation lines
	var current_mouse_pos = get_global_mouse_position()
	var mouse_distance_moved = current_mouse_pos.distance_to(last_mouse_position)
	current_swipe_speed = mouse_distance_moved / delta if delta > 0.0 else 0.0
	last_mouse_position = current_mouse_pos

	# =========================================================================
	# ⚔️ STATE A: ACTIVE MELEE SLAM PROCESSOR (CALIBRATED 80-DEGREE ARC)
	# 💡 FIXED: Read your target '80.0' degree angle variables natively inside the 
	# lerp equations, perfectly tightening your arc sways on both monitor halves!
	# =========================================================================
	if is_melee_attacking:
		melee_attack_life_timer -= delta
		var time_elapsed = active_melee_attack_duration - melee_attack_life_timer
		var current_local_offset_angle: float = 0.0
		
		# 📐 TARGET MELEE CALIBRATION
		var target_arc_radians: float = deg_to_rad(80.0) # Change to 75.0 if preferred!
		
		var swing_time = active_melee_attack_duration * MELEE_SWING_RATIO
		var freeze_time = active_melee_attack_duration * MELEE_FREEZE_RATIO
		
		if time_elapsed <= swing_time:
			var weight = time_elapsed / swing_time
			current_local_offset_angle = lerp(0.0, target_arc_radians, weight)
			if torch_sprite: torch_sprite.play("default")
		elif time_elapsed <= (swing_time + freeze_time):
			current_local_offset_angle = target_arc_radians
			if torch_sprite:
				torch_sprite.set_frame_and_progress(1, 0.0)
				torch_sprite.stop()
		elif time_elapsed < active_melee_attack_duration:
			var recovery_time = active_melee_attack_duration * MELEE_RECOVERY_RATIO
			var recovery_elapsed = time_elapsed - (swing_time + freeze_time)
			var weight = recovery_elapsed / recovery_time
			current_local_offset_angle = lerp(target_arc_radians, 0.0, weight)
			if torch_sprite: torch_sprite.play("default")
		else:
			is_melee_attacking = false
			melee_attack_life_timer = 0.0
			
		var mouse_is_left = get_global_mouse_position().x < global_position.x
		if mouse_is_left:
			_execute_math_mouse_aim(-current_local_offset_angle)
		else:
			_execute_math_mouse_aim(current_local_offset_angle)

	# =========================================================================
	# 🏹 STATE B: PRE-EXISTING SHOOT SWIPE PROCESSOR
	# =========================================================================
	elif is_attacking:
		attack_life_timer -= delta
		var time_elapsed = active_attack_duration - attack_life_timer
		var current_local_offset_angle: float = 0.0
		
		var swing_time = active_attack_duration * SWING_RATIO
		var freeze_time = active_attack_duration * FREEZE_RATIO
		
		if time_elapsed <= swing_time:
			var weight = time_elapsed / swing_time
			current_local_offset_angle = lerp(0.0, deg_to_rad(SLAM_ANGLE_DEGREES), weight)
			torch_sprite.play("default")
		elif time_elapsed <= (swing_time + freeze_time):
			current_local_offset_angle = deg_to_rad(SLAM_ANGLE_DEGREES)
			torch_sprite.set_frame_and_progress(1, 0.0)
			torch_sprite.stop()
		elif time_elapsed < active_attack_duration:
			var recovery_time = active_attack_duration * RECOVERY_RATIO
			var recovery_elapsed = time_elapsed - (swing_time + freeze_time)
			var weight = recovery_elapsed / recovery_time
			current_local_offset_angle = lerp(deg_to_rad(SLAM_ANGLE_DEGREES), 0.0, weight)
			torch_sprite.play("default")
		else:
			is_attacking = false
			attack_life_timer = 0.0
			
		_execute_math_mouse_aim(current_local_offset_angle * strike_multiplier)

	# =========================================================================
	# 🌊 STATE C: AMBIENT JUICE IDLE WAVING
	# =========================================================================
	else:
		if torch_sprite: torch_sprite.play("default")
		var angle_wave = sin(time_passed * WAVE_SPEED)
		var squash_wave = cos(time_passed * WAVE_SPEED * 1.5)
		var stretch_wave = sin(time_passed * WAVE_SPEED * 0.8)
		var fluid_wave_angle = (angle_wave + (stretch_wave * 0.3)) * deg_to_rad(ANGLE_STRENGTH)
		
		_execute_math_mouse_aim(fluid_wave_angle)
		
		if is_instance_valid(torch_sprite):
			var mouse_is_left = get_global_mouse_position().x < global_position.x
			var base_scale_x = -1.0 if mouse_is_left else 1.0
			torch_sprite.scale.x = base_scale_x + (squash_wave * SQUASH_STRENGTH)
			torch_sprite.scale.y = 1.0 + (stretch_wave * SQUASH_STRENGTH)
			
	# 💡 FIXED GATES: Input checkers have been completely trimmed out from here!
	# This lets your inventory UI loop stream attacks seamlessly without interference.

func shoot() -> void:
	if not is_ranged_card_equipped():
		return
	if current_fuel <= 0.0:
		return
	if can_shoot == false:
		return
		
	if camera and camera.has_method("add_shake"):
		camera.add_shake(2.5)
		
	# Lock both the ranged and melee attack channels to your fire_rate
	fire_cooldown = fire_rate
	melee_cooldown = fire_rate
	
	# 🪓 SWIPE-DOWN ANIMATION INITIALIZER
	active_attack_duration = min(0.21, fire_rate)
	is_attacking = true
	attack_life_timer = active_attack_duration
	
	if torch_sprite:
		torch_sprite.play("range")
		
	if has_node("woosh"):
		get_node("woosh").pitch_scale = randf_range(0.75, 1.2)
		get_node("woosh").play()
		
	# Determine whether the cursor is on the left or right of our body core
	var mouse_is_left = get_global_mouse_position().x < global_position.x
	strike_multiplier = -1.0 if mouse_is_left else 1.0
	
	# Resource deductions
	current_fuel = clamp(current_fuel - fuel_cost, 0.0, max_fuel)
	current_overheat_value = clamp(current_overheat_value + overheat_cost, 0.0, MAX_OVERHEAT)
	cooldown_delay_timer = COOL_DOWN_DELAY_WINDOW
	
	var ta = deg_to_rad(10.0)
	
	# 📊 A. DRIFT FUEL PROGRESS REGISTERS
	if is_instance_valid(fuel_bar):
		var fuel_glide = create_tween()
		fuel_glide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fuel_glide.tween_property(fuel_bar, "value", current_fuel, 0.80)
		if fuel_bar.pivot_offset == Vector2.ZERO:
			fuel_bar.pivot_offset = fuel_bar.size / 2.0
		var bar_juice = create_tween()
		var f_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var r_fuel_tilt = ta * f_multiplier
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(fuel_bar, "rotation", r_fuel_tilt, 0.05)
		bar_juice.tween_property(fuel_bar, "scale", Vector2(1.3, 1.3), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(fuel_bar, "rotation", -r_fuel_tilt, 0.05)
		bar_juice.set_parallel(true)
		bar_juice.tween_property(fuel_bar, "rotation", 0.0, 0.05)
		bar_juice.tween_property(fuel_bar, "scale", Vector2.ONE, 0.05)
		
	# 📊 B. DRIFT OVERHEAT PROGRESS REGISTERS
	if is_instance_valid(overheat):
		var heat_glide = create_tween()
		heat_glide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		heat_glide.tween_property(overheat, "value", current_overheat_value, 0.25)
		if overheat.pivot_offset == Vector2.ZERO:
			overheat.pivot_offset = overheat.size / 2.0
		var bar_juice = create_tween()
		var h_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var r_heat_tilt = ta * h_multiplier
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(overheat, "rotation", r_heat_tilt, 0.05)
		bar_juice.tween_property(overheat, "scale", Vector2(1.3, 1.3), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(overheat, "rotation", -r_heat_tilt, 0.05)
		bar_juice.set_parallel(true)
		bar_juice.tween_property(overheat, "rotation", 0.0, 0.05)
		bar_juice.tween_property(overheat, "scale", Vector2.ONE, 0.05)

	# =========================================================================
	# 🚀 ASYNC DYNAMIC BURST MULTISHOT MOTOR
	# 💡 FIXED: Runs Shot 1 instantly on frame 1, then triggers subsequent shots 
	# with a minor 0.05s step delay to prevent bullets from clumping together!
	# =========================================================================
	for shot_index in range(shoot_count):
		if shot_index == 0:
			# 💥 SHOT 1: Fires instantly on frame 1 to remove input lag
			_spawn_individual_burst_projectile()
		else:
			# ⏳ SHOTS 2+: Stagger the execution timeline frames
			var stagger_delay: float = shot_index * 0.05
			get_tree().create_timer(stagger_delay).timeout.connect(func():
				# Safety check: make sure the player didn't change levels or run dry mid-burst
				if is_instance_valid(self) and current_fuel > 0.0:
					_spawn_individual_burst_projectile()
			)

# Self-contained sub-helper wrapping your exact projectile scene data
func _spawn_individual_burst_projectile() -> void:
	if is_instance_valid(muzzle):
		var target_vector = (get_global_mouse_position() - global_position).normalized()
		var exact_tip_spawn_pos = global_position + (target_vector * BARREL_LENGTH_PIXELS)
		
		var player_node = get_parent()
		if is_instance_valid(player_node) and player_node.has_method("apply_weapon_kickback"):
			player_node.apply_weapon_kickback(target_vector)
			
		var particle_node = muzzle.find_child("FlameParticles", true, false) as GPUParticles2D
		if is_instance_valid(particle_node):
			muzzle.global_position = exact_tip_spawn_pos
			particle_node.restart()
			particle_node.emitting = true
			
		var base_aim_angle = target_vector.angle()
		var final_spread_angle = base_aim_angle + randf_range(-deg_to_rad(accuracy_spread_degrees), deg_to_rad(accuracy_spread_degrees))
		
		if projectile_scene:
			var bullet = projectile_scene.instantiate() as Area2D
			bullet.scale = projectile_size
			bullet.global_position = exact_tip_spawn_pos
			bullet.move_direction = Vector2.RIGHT.rotated(final_spread_angle)
			bullet.global_rotation = final_spread_angle
			get_tree().current_scene.add_child(bullet)
func _execute_math_mouse_aim(attack_offset: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var base_mouse_angle = (mouse_pos - global_position).angle()
	var mouse_is_left = mouse_pos.x < global_position.x
	
	if mouse_is_left:
		# Mirror matrix translation: sets up correct left-facing axes and overlays your swing offset
		global_rotation = base_mouse_angle + deg_to_rad(90.0) + attack_offset
	else:
		# Standard matrix translation: right-facing tracking line layered with your swing offset
		global_rotation = base_mouse_angle - deg_to_rad(0.0) + attack_offset
		
	if is_attacking and is_instance_valid(torch_sprite):
		torch_sprite.scale.y = 1.0

# =========================================================================
# 🧮 KINETIC DAMAGE EVALUATOR WITH FIRING RATE REGULATION
# =========================================================================
func execute_melee_swipe_action() -> void:
	if current_fuel <= 0.0: return
	if melee_cooldown > 0.0: return
	if can_shoot == false:
		return
	if not is_melee_card_equipped():
		return
	# 🎯 DEPLOY INSTANT HIT REGISTER: Runs physics queries before the cooldown locks it out!
	_check_swipe_collisions()
	
	is_melee_attacking = true
	melee_attack_life_timer = active_melee_attack_duration
	
	# Lock your weapon cooldown timers based on active card stats
	melee_cooldown = fire_rate
	fire_cooldown = fire_rate
	
	# 🎥 IMMEDIATE CAMERA SCREEN SHAKE FEEDBACK
	if camera and camera.has_method("add_shake"):
		camera.add_shake(5.0)
		
	# ⛽ RESOURCE COST DEDUCTIONS
	current_fuel = clamp(current_fuel - fuel_cost, 0.0, max_fuel)
	current_overheat_value = clamp(current_overheat_value + (overheat_cost), 0.0, MAX_OVERHEAT)
	cooldown_delay_timer = COOL_DOWN_DELAY_WINDOW
	
	# 📊 PROGRESS BAR UPDATES (Direct Value Injection)
	if is_instance_valid(fuel_bar):
		fuel_bar.value = current_fuel
		fuel_bar.pivot_offset = fuel_bar.size / 2.0
		var fuel_pop = create_tween()
		fuel_pop.tween_property(fuel_bar, "scale", Vector2(1.2, 1.2), 0.04)
		fuel_pop.chain().tween_property(fuel_bar, "scale", Vector2.ONE, 0.08)
		
	if is_instance_valid(overheat):
		overheat.value = current_overheat_value
		overheat.pivot_offset = overheat.size / 2.0
		var heat_pop = create_tween()
		heat_pop.tween_property(overheat, "scale", Vector2(1.2, 1.2), 0.04)
		heat_pop.chain().tween_property(overheat, "scale", Vector2.ONE, 0.08)
	if SWIPE_TRAIL_SCENE:
			var target_vector = (get_global_mouse_position() - global_position).normalized()
			var exact_tip_spawn_pos = global_position + (target_vector * BARREL_LENGTH_PIXELS)
			var base_aim_angle = target_vector.angle()
			var final_spread_angle = base_aim_angle + randf_range(-deg_to_rad(accuracy_spread_degrees), deg_to_rad(accuracy_spread_degrees))
			var particles = SWIPE_TRAIL_SCENE.instantiate() as GPUParticles2D
			particles.emitting = true
			particles.global_position = exact_tip_spawn_pos
			particles.global_rotation = final_spread_angle
			get_tree().current_scene.add_child(particles)
		
	if has_node("woosh"):
		get_node("woosh").pitch_scale = randf_range(0.75, 1.2)
		get_node("woosh").play()
func _check_swipe_collisions() -> void:
	var space_state = get_world_2d().direct_space_state
	if not space_state: return
	
	var flat_melee_damage = SWIPE_DAMAGE
	var swipe_direction: Vector2 = Vector2.ZERO
	
	# =========================================================================
	# 📐 PIXEL-PERFECT CONE FILTER
	# 💡 FIXED: Calculates the arc center directly from the current mouse position
	# to guarantee the 90-degree damage zone matches your visual attack swing!
	# =========================================================================
	var mouse_pos = get_global_mouse_position()
	var arc_center_angle = (mouse_pos - global_position).angle()
	var max_allowed_angle_deviation = deg_to_rad(45.0) # 45° left + 45° right = 90° total cone

	# Set up a circle overlap query centered exactly on your weapon core
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	
	# Reach distance expands to your full weapon barrel width plus a safety padding
	circle_shape.radius = BARREL_LENGTH_PIXELS + 32.0
	
	query.shape = circle_shape
	query.transform = Transform2D(0.0, global_position) 
	query.collision_mask = melee_zone.collision_mask if is_instance_valid(melee_zone) else 1
	
	# 💡 FIXED: Enabled both flags so the script detects CharacterBodies AND Area2D enemies!
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	# 📊 SCAN RADIAL SECTOR AREA
	var hit_results = space_state.intersect_shape(query)
	for result in hit_results:
		var hit_collider = result.get("collider")
		if is_instance_valid(hit_collider) and (hit_collider.is_in_group("enemies") or hit_collider.get_parent().is_in_group("enemies")):
			
			# Get the true enemy node reference whether it's an Area or a Body
			var enemy_node = hit_collider
			if not enemy_node.is_in_group("enemies") and enemy_node.get_parent().is_in_group("enemies"):
				enemy_node = hit_collider.get_parent()
				
			if enemy_node.has_method("take_damage"):
				# Find the absolute angle pointing from player to this enemy
				var angle_to_enemy = (enemy_node.global_position - global_position).angle()
				
				# Calculate the angular difference to check if they sit inside our 90-degree cone
				var angular_distance = abs(angle_difference(arc_center_angle, angle_to_enemy))
				
				if angular_distance <= max_allowed_angle_deviation:
					# 💥 CRUNCH: Target verified inside the 90° slice! Apply damage and knockback.
					swipe_direction = (enemy_node.global_position - global_position).normalized()
					enemy_node.take_damage(flat_melee_damage, swipe_direction)
				
	# =========================================================================
	# ⛽ UNCONDITIONAL RESOURCE DEDUCTIONS & VISUAL JUICE
	# =========================================================================
	var particle_node = muzzle.find_child("FlameParticles", true, false) as GPUParticles2D
	if is_instance_valid(particle_node):
		particle_node.top_level = false
		particle_node.emitting = true
	cooldown_delay_timer = COOL_DOWN_DELAY_WINDOW
	
	var ta = deg_to_rad(10.0)
	
	if is_instance_valid(fuel_bar):
		var fuel_glide = create_tween()
		fuel_glide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fuel_glide.tween_property(fuel_bar, "value", current_fuel, 0.25)
		if fuel_bar.pivot_offset == Vector2.ZERO: fuel_bar.pivot_offset = fuel_bar.size / 2.0
		var bar_juice = create_tween()
		var f_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var r_fuel_tilt = ta * f_multiplier
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(fuel_bar, "rotation", r_fuel_tilt, 0.05)
		bar_juice.tween_property(fuel_bar, "scale", Vector2(1.3, 1.3), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(fuel_bar, "rotation", -r_fuel_tilt, 0.05)
		bar_juice.set_parallel(true)
		bar_juice.tween_property(fuel_bar, "rotation", f_multiplier * 0.5, 0.05)
		bar_juice.tween_property(fuel_bar, "scale", Vector2(1.1, 1.1), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.tween_property(fuel_bar, "rotation", -r_fuel_tilt * 0.3, 0.05)
		bar_juice.chain().set_parallel(true)
		bar_juice.tween_property(fuel_bar, "rotation", 0.0, 0.05)
		bar_juice.tween_property(fuel_bar, "scale", Vector2.ONE, 0.05)
		
	if is_instance_valid(overheat):
		var heat_glide = create_tween()
		heat_glide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		heat_glide.tween_property(overheat, "value", current_overheat_value, 0.25)
		if overheat.pivot_offset == Vector2.ZERO: overheat.pivot_offset = overheat.size / 2.0
		var bar_juice = create_tween()
		var h_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var r_heat_tilt = ta * h_multiplier
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(overheat, "rotation", r_heat_tilt, 0.05)
		bar_juice.tween_property(overheat, "scale", Vector2(1.3, 1.3), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(overheat, "rotation", -r_heat_tilt, 0.05)
		bar_juice.set_parallel(true)
		bar_juice.tween_property(overheat, "rotation", h_multiplier * 0.5, 0.05)
		bar_juice.tween_property(overheat, "scale", Vector2(1.1, 1.1), 0.05)
		bar_juice.chain().set_parallel(false)
		bar_juice.tween_property(overheat, "rotation", -r_heat_tilt * 0.3, 0.05)
		bar_juice.chain().set_parallel(true)
		bar_juice.tween_property(overheat, "rotation", 0.0, 0.05)
		bar_juice.tween_property(overheat, "scale", Vector2.ONE, 0.05)
		if camera and camera.has_method("add_shake"):
				camera.add_shake(3.0)
				
func _on_melee_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not enemies_currently_overlapping.has(body):
		enemies_currently_overlapping.append(body as CharacterBody2D)

func _on_melee_zone_body_exited(body: Node2D) -> void:
	if enemies_currently_overlapping.has(body):
		enemies_currently_overlapping.erase(body)
func is_ranged_card_equipped() -> bool:
	var ui_node = globals.inventory
	if is_instance_valid(ui_node) and ui_node.inv != null:
		for i in range(72):
			if i < ui_node.inv.items.size() and ui_node.inv.items[i] != null:
				# Sprite frame 2 is your dedicated Ranged Attack Card!
				if ui_node.inv.items[i].card_sprite_frame == 2:
					return true
	return false

func is_melee_card_equipped() -> bool:
	var ui_node = globals.inventory
	if is_instance_valid(ui_node) and ui_node.inv != null:
		for i in range(72):
			if i < ui_node.inv.items.size() and ui_node.inv.items[i] != null:
				# Sprite frame 3 is your dedicated Melee Attack Card!
				if ui_node.inv.items[i].card_sprite_frame == 3:
					return true
	return false
