extends TextureRect

const GAMEPLAY_SCENE_PATH: String = "res://main.tscn"
func _ready() -> void:
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, 0.0)
func _on_play_pressed() -> void:
	# 1. Instantly disable the button inputs so the player can't double-click spam
	$play.disabled = true
	$quit.disabled = true
	$settings.disabled = true
	
	# =========================================================================
	# 🔒 THE DEEP HOVER MUTING CORE (PLAY BUTTON PRESS)
	# 💡 FIXED: Shut off all child button mouse raycasts during the exit slides!
	# =========================================================================
	_set_buttons_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	
	# 2. Cache the absolute baseline center position of your menu canvas right now
	var original_menu_y = position.y
	
	# 3. Create a single, sequence-locked structural code timeline
	var menu_transition = create_tween()
	
	# =========================================================================
	# 📈 PHASE A: THE SNAPPY ANTICIPATION POP (UPWARD MOUSE JUMP)
	# =========================================================================
	menu_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	menu_transition.tween_property(self, "global_position:y", original_menu_y - 80.0, 0.40)
	
	# =========================================================================
	# 📉 PHASE B: THE GRAVITATIONAL SLAM DOWNWARD (Stutter-Free Plunge)
	# =========================================================================
	var window_height = get_viewport_rect().size.y
	menu_transition.chain().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	menu_transition.tween_property(self, "global_position:y", original_menu_y + window_height + 60.0, 0.38)
	
	# 🎬 PHASE C: SCENE SWAP
	menu_transition.chain().tween_callback(func():
		get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	)

# =========================================================================
# 📉 GRADUAL FADE-TO-BLACK QUIT ENGINE
# =========================================================================
func _on_quit_pressed() -> void:
	# 1. Lock buttons instantly to protect the sequence threads from multi-click bugs
	$play.disabled = true
	$quit.disabled = true
	$settings.disabled = true
	
	# 🔒 FIXED: Shut off all child button mouse raycasts during the fade out!
	_set_buttons_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	
	# 2. Programmatically create a full-screen masking color rectangle
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	
	# Ensure the mask stretches completely across any monitor window scale natively
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Lock mouse filters to 'Ignore' so it never intercepts lingering hover nodes mid-frame
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 3. Inject it into the parent layer so it draws on top of all menu elements
	add_child(fade_overlay)
	
	# 4. Initialize the opacity layer to absolute transparency
	fade_overlay.modulate.a = 0.0
	
	# 5. Execute a smooth fading interpolation timeline track
	var quit_fade = create_tween()
	quit_fade.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	# Glide the alpha opacity up to full solid dark over 0.50 seconds
	quit_fade.tween_property(fade_overlay, "modulate:a", 1.0, 0.40)
	
	# 🎬 THE FINAL EXIT CALLBACK: The frame the monitor goes pitch black, quit safely!
	quit_fade.tween_callback(func():
		get_tree().quit()
	)

# =========================================================================
# 🧮 DEEP CHILD UTILITY RECURSION SCANNER
# 💡 FIXED: Recursively loops downward into your menu layout hierarchy, finding
# every individual button scene node and forcing its input state to lock!
# =========================================================================
func _set_buttons_mouse_filter(parent_node: Node, target_filter: Control.MouseFilter) -> void:
	for child in parent_node.get_children():
		if child is Button:
			child.mouse_filter = target_filter
		if child.get_child_count() > 0:
			_set_buttons_mouse_filter(child, target_filter)
