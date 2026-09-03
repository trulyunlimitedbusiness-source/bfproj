extends CanvasLayer

var is_on = false
var is_opened = false
var menu_tween: Tween = null

# 💾 THERMAL CORE MEMORY FILTER
var true_center_y: float = 0.0
var has_cached_center: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	is_on = false

func _process(_delta: float) -> void:
	if !globals.is_dead:
		if Input.is_action_just_pressed("ui_cancel"):
			# 🔒 SPECIAL INTERRUPT GUARD: Blocks inputs if a tween is actively running mid-frame!
			if menu_tween and menu_tween.is_valid(): 
				return
				
			is_on = !is_on
			if is_on && !is_opened:
				open_menu()
			if not is_on && is_opened:
				close_menu()

func open_menu() -> void:
	$menu/TextureRect/b1.disabled = true
	$menu/TextureRect/b2.disabled = true
	$menu/TextureRect/b3.disabled = true
	is_opened = true
	get_tree().paused = true
	visible = true
	
	var ui_container = get_child(0) as Control 
	
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
		# Cache the center Y-coordinate exactly ONCE the very first time you open the menu
		if not has_cached_center:
			true_center_y = ui_container.position.y
			has_cached_center = true
		
		# =========================================================================
		# 🔒 THE DEEP HOVER MUTING ENGINE (ENTRY HOOK)
		# 💡 FIXED: We manually force every button to ignore mouse tracking 
		# the exact frame the entry slide initiates!
		# =========================================================================
		_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_IGNORE)
		ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Set the pivot offset to dead center so it expands symmetrically
		ui_container.pivot_offset = ui_container.size / 2.0
		
		# Pull the window height and snap the panel completely off-screen below the monitor rim
		var screen_height = get_viewport().get_visible_rect().size.y
		ui_container.position.y = screen_height + 50.0 
		
		ui_container.modulate.a = 0.0
		ui_container.scale = Vector2(0.85, 0.85) 
		
		# Build a pause-exempt parallel entry animation track
		menu_tween = create_tween()
		menu_tween.set_parallel(true)
		menu_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Rocket the panel straight up to your locked, safe center position over 0.50s
		menu_tween.tween_property(ui_container, "position:y", true_center_y, 0.50)
		menu_tween.tween_property(ui_container, "modulate:a", 1.0, 0.25)
		menu_tween.tween_property(ui_container, "scale", Vector2.ONE, 0.50)
		
		# 🔓 WAKE GATES: Re-enable button mouse tracking only AFTER the slide pops into center home
		menu_tween.chain().tween_callback(func():
			if is_instance_valid(ui_container):
				ui_container.mouse_filter = Control.MOUSE_FILTER_STOP
				_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_STOP)
				$menu/TextureRect/b1.disabled = false
				$menu/TextureRect/b2.disabled = false
				$menu/TextureRect/b3.disabled = false
		)

func close_menu() -> void:
	$menu/TextureRect/b1.disabled = true
	$menu/TextureRect/b2.disabled = true
	$menu/TextureRect/b3.disabled = true
	var ui_container = get_child(0) as Control
	
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
		# 🔒 FIXED: Mute all individual button hover checks during exit slides!
		ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_IGNORE)
			
		var screen_height = get_viewport().get_visible_rect().size.y
		
		# Build a pause-exempt parallel exit timeline track
		menu_tween = create_tween()
		menu_tween.set_parallel(true)
		menu_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# Rocket the panel back down past the bottom rim of the screen over 0.35s
		menu_tween.tween_property(ui_container, "position:y", screen_height + 50.0, 0.50)
		menu_tween.tween_property(ui_container, "modulate:a", 0.0, 0.20)
		menu_tween.tween_property(ui_container, "scale", Vector2(0.85, 0.85), 0.50)
		
		# The exact millisecond the panel hits the bottom, wipe variables and unpause!
		menu_tween.chain().tween_callback(func():
			is_opened = false
			visible = false
			get_tree().paused = false
			
			if is_instance_valid(ui_container):
				ui_container.position.y = true_center_y
				ui_container.modulate.a = 1.0
				ui_container.scale = Vector2.ONE
				ui_container.mouse_filter = Control.MOUSE_FILTER_STOP
				_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_STOP)
		)

func _on_b_1_pressed() -> void:
	var ui_container = get_child(0) as Control
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
		# 🔒 FIXED: Shut off deep child hover nodes completely
		ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_IGNORE)
		
		menu_tween = create_tween()
		
		# 📈 PHASE A: ANTICIPATION POP DOWNWARD (0.10s)
		menu_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		menu_tween.tween_property(ui_container, "position:y", true_center_y + 20.0, 0.10)
		
		# 📉 PHASE B: ROCKET SLAM UPWARD OFF THE MONITOR TOP (0.38s)
		menu_tween.chain().set_parallel(true)
		menu_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		menu_tween.tween_property(ui_container, "position:y", true_center_y - 750.0, 0.38)
		menu_tween.tween_property(ui_container, "modulate:a", 0.0, 0.22)
		menu_tween.tween_property(ui_container, "scale", Vector2(0.80, 0.80), 0.38)
		
		# 🎬 PHASE C: AIRTIGHT RELOAD CALLBACK
		menu_tween.chain().tween_callback(func():
			is_opened = false
			visible = false
			get_tree().paused = false
			get_tree().reload_current_scene()
		)
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_b_2_pressed() -> void:
	pass # Replace with function body.

func _on_b_3_pressed() -> void:
	var ui_container = get_child(0) as Control
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
		# 🔒 FIXED: Shut off deep child hover nodes completely
		ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_IGNORE)
		
		menu_tween = create_tween()
		menu_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		menu_tween.tween_property(ui_container, "position:y", true_center_y + 20.0, 0.10)
		
		menu_tween.chain().set_parallel(true)
		menu_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		menu_tween.tween_property(ui_container, "position:y", true_center_y - 750.0, 0.38)
		menu_tween.tween_property(ui_container, "modulate:a", 0.0, 0.22)
		menu_tween.tween_property(ui_container, "scale", Vector2(0.80, 0.80), 0.38)
		
		menu_tween.chain().tween_callback(func():
			is_opened = false
			visible = false
			get_tree().paused = false
			get_tree().change_scene_to_file("res://main_menu.tscn")
		)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main_menu.tscn")

# =========================================================================
# 🧮 DEEP CHILD UTILITY RECURSION SCANNER
# 💡 FIXED: This helper loops through your container folder depth, finding
# every individual button scene node and forcing its input state to lock!
# =========================================================================
func _set_buttons_mouse_filter(parent_node: Node, target_filter: Control.MouseFilter) -> void:
	for child in parent_node.get_children():
		if child is Button:
			child.mouse_filter = target_filter
		# If you nested your buttons inside deeper sub-folders, recurse downward!
		if child.get_child_count() > 0:
			_set_buttons_mouse_filter(child, target_filter)
