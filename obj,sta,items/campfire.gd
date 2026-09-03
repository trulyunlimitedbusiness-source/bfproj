extends Area2D

var in_range = false
var is_used = false

@onready var fire = $fire
@onready var cfsprite = $AnimatedSprite2D
@onready var logs = $AnimatedSprite2D2 # 🪵 YOUR LOCAL LOGS STATIC NODE REGISTER
@onready var tsprite = $Sprite2D

# ⏱️ COOLDOWN CONFIGURATORS
const RECHARGE_TIME_SECONDS: float = 10.0 # 2 minutes exact clock duration
var cooldown_timer: float = 0.0
var targets_in_fire: Array[Node2D] = []
var damage_timestamps: Dictionary = {} 
const FLAME_DAMAGE_TICK_RATE: float = 0.45 
const FLAME_DAMAGE_AMOUNT: float = 8.0 

func _ready() -> void:
	tsprite.visible = false
	in_range = false
	$Label.visible = false
	is_used = false
	cooldown_timer = 0.0
	globals.campfire = self
	# Duplicate the shader material so separate campfires don't share the same cooldown progress
	if is_instance_valid(logs) and logs.material:
		logs.material = logs.material.duplicate()
		logs.material.set_shader_parameter("dark_cooldown_factor", 0.0)

	if is_instance_valid(fire):
		if not fire.body_entered.is_connected(_on_fire_body_entered):
			fire.body_entered.connect(_on_fire_body_entered)
		if not fire.body_exited.is_connected(_on_fire_body_exited):
			fire.body_exited.connect(_on_fire_body_exited)

func _process(delta: float) -> void:
	if is_instance_valid(cfsprite):
		cfsprite.play("default")
	if is_used:
		if cooldown_timer > 0.0:
			cooldown_timer -= delta
			# Force-lock the shader parameter at 1.0 (fully dark) while active
			if is_instance_valid(logs) and logs.material:
				logs.material.set_shader_parameter("dark_cooldown_factor", 1.0)
		else:
			is_used = false
			cooldown_timer = 0.0
			
			if is_instance_valid(logs) and logs.material:
				logs.material.set_shader_parameter("dark_cooldown_factor", 0.0)
				
			if in_range:
				$Label.text = "[E]"
				$Label.visible = true

	if in_range and not is_used:
		if Input.is_action_pressed("interact"):
			if globals.torch.current_fuel < 100.0:
				is_used = true
				globals.campfire = self
				use()

	# =========================================================================
	# 🔥 DECOUPLED STAMP DAMAGE CORE
	# =========================================================================
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for i in range(targets_in_fire.size() - 1, -1, -1):
		var target = targets_in_fire[i]
		if not is_instance_valid(target) or ("is_dead" in target and target.is_dead) or (target == globals.player and globals.is_dead):
			targets_in_fire.remove_at(i)
			
	for target in targets_in_fire:
		var target_id = target.get_instance_id()
		if not damage_timestamps.has(target_id) or current_time >= damage_timestamps[target_id]:
			damage_timestamps[target_id] = current_time + FLAME_DAMAGE_TICK_RATE
			
			if target.is_in_group("player") and target.has_method("damage"):
				target.damage(FLAME_DAMAGE_AMOUNT)
			elif target.is_in_group("enemies") and target.has_method("take_damage"):
				var push_vec = (target.global_position - global_position).normalized()
				target.take_damage(FLAME_DAMAGE_AMOUNT, push_vec)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_range = true
		if is_used:
			$Label.add_theme_font_size_override("font_size", 6)
			$Label.text = "Can't ignite yet"
		else:
			$Label.text = "[E]"
			if is_instance_valid(logs):
				logs.frame = 1
		$Label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_range = false
		$Label.visible = false
		if is_instance_valid(logs):
			logs.frame = 0

func use() -> void:
	$Label.visible = false
	
	# Block torch controls while refuelling so players can't fire ghost projectiles
	if is_instance_valid(globals.torch):
		globals.torch.visible = false
		globals.torch.set_process(false) # 🛑 Blocks inputs completely
		
	tsprite.visible = true
	if globals.torch.current_fuel <= 0:
		tsprite.frame = 1
	else:
		tsprite.frame = 0
	
	# ⏱️ Wait 1.0 second for the refuelling timer countdown lock to complete
	await get_tree().create_timer(1.0).timeout
	
	# =========================================================================
	# 💥 THE EXPLOSIVE IMPACT JUICE PIPELINE
	# =========================================================================
	if has_node("ignite"):
		$ignite.pitch_scale = randf_range(0.9, 1.1)
		$ignite.play()
	globals.camera.add_shake(3.8)
	
	tsprite.rotation = 0.0
	cfsprite.rotation = 0.0
	if is_instance_valid(logs): 
		logs.rotation = 0.0
	
	var squish_out = Vector2(1.45, 0.65) 
	var stretch_up = Vector2(0.85, 1.25) 
	var micro_wobble = Vector2(1.10, 0.95) 
	
	var station_juice = create_tween()
	station_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	station_juice.tween_property(self, "scale", squish_out, 0.05)
	station_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	station_juice.tween_property(self, "scale", stretch_up, 0.06)
	station_juice.tween_property(self, "scale", micro_wobble, 0.06)
	station_juice.tween_property(self, "scale", Vector2.ONE, 0.08)
	
	# ⏱️ Let the physical spring wiggle animation play out completely
	await get_tree().create_timer(0.3).timeout
	
	# =========================================================================
	# ❄️ THE RECOVERY & DELAYED RECHARGE PIPELINE
	# =========================================================================
	if is_instance_valid(globals.torch):
		globals.torch.visible = true
		globals.torch.set_process(true) # 🔓 Re-enable weapon input frames safely
		globals.torch.current_fuel = 100.0
		
	tsprite.visible = false
	is_used = true
	# Engage the binary cooldown clock data
	cooldown_timer = RECHARGE_TIME_SECONDS
	if is_instance_valid(logs) and logs.material:
		logs.material.set_shader_parameter("dark_cooldown_factor", 1.0)
		
	if in_range:
		$Label.add_theme_font_size_override("font_size", 6)
		$Label.text = "Can't refuel yet"
		$Label.visible = true
	
	# =========================================================================
	# 📈 FUEL BAR CELEBRATORY RESETS & TILT JUICE
	# =========================================================================
	var ui_fuel_bar = globals.torch.fuel_bar if is_instance_valid(globals.torch) and "fuel_bar" in globals.torch else null
	if is_instance_valid(ui_fuel_bar):
		var heat_flush = create_tween()
		heat_flush.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		heat_flush.tween_property(ui_fuel_bar, "value", 100.0, 0.35)
		
		if ui_fuel_bar.pivot_offset == Vector2.ZERO:
			ui_fuel_bar.pivot_offset = ui_fuel_bar.size / 2.0
			
		var bar_juice = create_tween()
		var ta = deg_to_rad(10.0)
		var random_direction_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var randomized_tilt_angle = ta * random_direction_multiplier
		
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(ui_fuel_bar, "rotation", randomized_tilt_angle, 0.05)
		bar_juice.tween_property(ui_fuel_bar, "scale", Vector2(1.3, 1.3), 0.05)
		
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(ui_fuel_bar, "rotation", -randomized_tilt_angle, 0.05)
		
		bar_juice.set_parallel(true)
		bar_juice.tween_property(ui_fuel_bar, "rotation", randomized_tilt_angle * 0.5, 0.05)
		bar_juice.tween_property(ui_fuel_bar, "scale", Vector2(1.1, 1.1), 0.05)
		
		bar_juice.chain().set_parallel(false)
		bar_juice.tween_property(ui_fuel_bar, "rotation", -randomized_tilt_angle * 0.3, 0.05)
		
		bar_juice.chain().set_parallel(true)
		bar_juice.tween_property(ui_fuel_bar, "rotation", 0.0, 0.05)
		bar_juice.tween_property(ui_fuel_bar, "scale", Vector2.ONE, 0.05)

# =========================================================================
# ⚔️ FIRE AREA DETECTOR SIGNAL INTERSECTIONS
# =========================================================================
func _on_fire_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemies"):
		if not targets_in_fire.has(body):
			targets_in_fire.append(body)
			var body_id = body.get_instance_id()
			if damage_timestamps.has(body_id): 
				damage_timestamps.erase(body_id)

func _on_fire_body_exited(body: Node2D) -> void:
	if targets_in_fire.has(body): 
		targets_in_fire.erase(body)
