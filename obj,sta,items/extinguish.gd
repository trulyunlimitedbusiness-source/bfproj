extends Area2D

var in_range = false
var is_used = false

@onready var exsprite = $AnimatedSprite2D

# ⏱️ COOLDOWN CONFIGURATORS
const RECHARGE_TIME_SECONDS: float = 10.0 # 2 minutes exact clock duration
var cooldown_timer: float = 0.0
var health_cost = 1.0
@onready var tsprite = $Sprite2D

func _ready() -> void:
	globals.extinguish_station = self
	tsprite.visible = false
	in_range = false
	$Label.visible = false
	is_used = false
	cooldown_timer = 0.0
	
	# Duplicate the shader material so separate stations don't share the same cooldown progress
	if is_instance_valid(exsprite) and exsprite.material:
		exsprite.material = exsprite.material.duplicate()
		exsprite.material.set_shader_parameter("dark_cooldown_factor", 0.0)

func _process(delta: float) -> void:
	# =========================================================================
	# ⏳ UNIFIED MECHANICAL DELTA COOLDOWN TRACKER
	# 💡 FIXED: Operates your countdown step-by-step! Keeps the shader flat dark
	# while counting down, and snaps it back to full color the frame it ends.
	# =========================================================================
	if is_used:
		if cooldown_timer > 0.0:
			cooldown_timer -= delta
			# Force-lock the shader parameter at 1.0 (fully dark) while active
			if is_instance_valid(exsprite) and exsprite.material:
				exsprite.material.set_shader_parameter("dark_cooldown_factor", 1.0)
		else:
			# 🔓 THE RECHARGE MOMENT: Snap back to full vibrant color instantly!
			is_used = false
			cooldown_timer = 0.0
			
			if is_instance_valid(exsprite) and exsprite.material:
				exsprite.material.set_shader_parameter("dark_cooldown_factor", 0.0)
				
			if in_range:
				$Label.text = "[E]"
				$Label.visible = true

	if in_range and not is_used:
		if Input.is_action_pressed("interact"):
			if is_instance_valid(globals.torch) and globals.torch.is_overheat_locked:
				is_used = true
				use()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_range = true
		if is_used:
			$Label.add_theme_font_size_override("font_size", 6)
			$Label.text = "Can't extinguish yet"
		else:
			$Label.text = "[E]"
			if is_instance_valid(exsprite):
				exsprite.frame = 1
		$Label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		in_range = false
		$Label.visible = false
		if is_instance_valid(exsprite):
			exsprite.frame = 0

func use() -> void:
	$Label.visible = false
	
	# =========================================================================
	# 🔒 THE AIRTIGHT INPUT LOCKOUT ENGINE
	# =========================================================================
	if is_instance_valid(globals.torch):
		globals.torch.visible = false
		globals.torch.set_process(false) # 🛑 Blocks the torch's input frame updates entirely!
		
	tsprite.visible = true
	
	
	# ⏱️ Wait 1.0 second for the mechanical alignment countdown lock to complete
	await get_tree().create_timer(1.0).timeout
	
	# =========================================================================
	# 💥 THE EXPLOSIVE IMPACT JUICE PIPELINE
	# =========================================================================
	$burning.emitting = true
	$extinguish.pitch_scale = randf_range(0.4, 0.6)
	$extinguish.play()
	globals.camera.add_shake(3.8)
	globals.player.damage(health_cost)
	
	# Hard clear any residue lean angles left over from older tests
	tsprite.rotation = 0.0
	exsprite.rotation = 0.0
	
	# Establish our high-juice squeeze multipliers (Flatten down hard, expand wide!)
	var squish_out = Vector2(1.45, 0.65)
	var stretch_up = Vector2(0.85, 1.25)
	var micro_wobble = Vector2(1.10, 0.95)
	
	var station_juice = create_tween()
	
	# 🚀 PHASE 1: THE HEAVY MECHANICAL EXPLOSION SLAM (0.05s)
	station_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	station_juice.tween_property(self, "scale", squish_out, 0.05)
	
	# 🔄 PHASE 2: THE JELLY BOUNCE-BACK RECOIL OSCILLATION (0.06s)
	station_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	station_juice.tween_property(self, "scale", stretch_up, 0.06)
	
	# 📉 PHASE 3: THE DECAYING WIGGLE SHAKE (0.06s)
	station_juice.tween_property(self, "scale", micro_wobble, 0.06)
	
	# 🏁 PHASE 4: FINAL ABSOLUTE VECTOR RESTORATION RECOVERY (0.08s)
	station_juice.tween_property(self, "scale", Vector2.ONE, 0.08)
	
	# ⏱️ Let the physical spring wobble and stretch animations play out fully first!
	await get_tree().create_timer(0.3).timeout
	
	# =========================================================================
	# ❄️ THE RECOVERY & DELAYED RECHARGE PIPELINE
	# 💡 FIXED: We seed the delta clock tracker and engage the full dark shadow 
	# parameter the exact microsecond your weapons return to your hands!
	# =========================================================================
	if is_instance_valid(globals.torch):
		globals.torch.visible = true
		globals.torch.set_process(true) # 🔓 Wake the weapon back up for input processing!
		globals.torch.current_overheat_value = 0.0
		globals.torch.is_overheat_locked = false
		
	tsprite.visible = false
	
	# Engage the binary cooldown clock data
	cooldown_timer = RECHARGE_TIME_SECONDS
	if is_instance_valid(exsprite) and exsprite.material:
		exsprite.material.set_shader_parameter("dark_cooldown_factor", 1.0)
	is_used = true
	# If the player is STILL standing inside the zone right as the swap ends, instantly show text
	if in_range:
		$Label.add_theme_font_size_override("font_size", 6)
		$Label.text = "Can't extinguish yet"
		$Label.visible = true
		
	# =========================================================================
	# 📈 OVERHEAT BAR CELEBRATORY RESETS & TILT JUICE
	# =========================================================================
	var ui_overheat_bar = globals.torch.overheat if is_instance_valid(globals.torch) and "overheat" in globals.torch else null
	
	if is_instance_valid(ui_overheat_bar):
		var heat_flush = create_tween()
		heat_flush.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		heat_flush.tween_property(ui_overheat_bar, "value", 0.0, 0.35)
		
		if ui_overheat_bar.pivot_offset == Vector2.ZERO:
			ui_overheat_bar.pivot_offset = ui_overheat_bar.size / 2.0
			
		var bar_juice = create_tween()
		var ta = deg_to_rad(10.0)
		var random_direction_multiplier: float = 1.0 if randf() > 0.5 else -1.0
		var randomized_tilt_angle = ta * random_direction_multiplier
		
		bar_juice.set_parallel(true)
		bar_juice.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bar_juice.tween_property(ui_overheat_bar, "rotation", randomized_tilt_angle, 0.05)
		bar_juice.tween_property(ui_overheat_bar, "scale", Vector2(1.3, 1.3), 0.05)
		
		bar_juice.chain().set_parallel(false)
		bar_juice.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bar_juice.tween_property(ui_overheat_bar, "rotation", -randomized_tilt_angle, 0.05)
		
		bar_juice.set_parallel(true)
		bar_juice.tween_property(ui_overheat_bar, "rotation", randomized_tilt_angle * 0.5, 0.05)
		bar_juice.tween_property(ui_overheat_bar, "scale", Vector2(1.1, 1.1), 0.05)
		
		bar_juice.chain().set_parallel(false)
		bar_juice.tween_property(ui_overheat_bar, "rotation", -randomized_tilt_angle * 0.3, 0.05)
		
		bar_juice.chain().set_parallel(true)
		bar_juice.tween_property(ui_overheat_bar, "rotation", 0.0, 0.05)
		bar_juice.tween_property(ui_overheat_bar, "scale", Vector2.ONE, 0.05)
	
