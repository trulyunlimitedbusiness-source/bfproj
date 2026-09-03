extends CanvasLayer

var menu_tween: Tween = null
var true_center_y: float = 0.0
var is_opened = false
var has_cached_center: bool = false

func _ready() -> void:
	# =========================================================================
	# 💀 MASTER CORE INITIALIZATION
	# We force this layer to process constantly regardless of whether the rest 
	# of the world tree pauses, and keep it safely invisible when the match begins.
	# =========================================================================
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	is_opened = false

func _process(_delta: float) -> void:
	# =========================================================================
	# 📡 THE DEATH TRIGGER LISTENER
	# This scans your global game state registers every single frame tick.
	# The exact frame the player dies, it deploys the intro popup animation!
	# =========================================================================
	if globals.is_dead and not is_opened:
		open_death_menu_with_juice()

func open_death_menu_with_juice() -> void:
	await get_tree().create_timer(0.4).timeout
	is_opened = true
	visible = true
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, 0.0)
	# Freeze all background entities (enemies, projectiles, scrolling map tiles)
	get_tree().paused = true
	
	var ui_container = get_child(0) as Control
	
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
		# Cache the initial layout alignment coordinates exactly once
		if not has_cached_center:
			true_center_y = ui_container.position.y
			has_cached_center = true
			
		# Mute mouse tracking and lock button grids during entry flight
		ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_IGNORE)
		
		# Set the layout anchor pivot point to the absolute geometric core of your panel
		ui_container.pivot_offset = ui_container.size / 2.0
		
		# Fetch active screen height bounds and snap the container below the monitor rim instantly
		var screen_height = get_viewport().get_visible_rect().size.y
		ui_container.position.y = screen_height + 50.0
		
		# Set introductory visual failure baselines (slightly shrunken and clear)
		ui_container.modulate.a = 0.0
		ui_container.scale = Vector2(0.85, 0.85)
		
		# Build a pause-exempt parallel entry animation track
		menu_tween = create_tween()
		menu_tween.set_parallel(true)
		menu_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# 📈 Rocket the panel straight up from the floor to center focus over 0.50 seconds
		menu_tween.tween_property(ui_container, "position:y", true_center_y, 0.50)
		menu_tween.tween_property(ui_container, "modulate:a", 1.0, 0.25)
		menu_tween.tween_property(ui_container, "scale", Vector2.ONE, 0.50)
		
		# 🔓 WAKE GATES: Re-enable button clicks only AFTER the card finishes its bouncy slide
		menu_tween.chain().tween_callback(func():
			if is_instance_valid(ui_container):
				ui_container.mouse_filter = Control.MOUSE_FILTER_STOP
				_set_buttons_mouse_filter(ui_container, Control.MOUSE_FILTER_STOP)
		)

func _on_b_1_pressed() -> void:
	var ui_container = get_child(0) as Control
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
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
			globals.is_dead = false
			get_tree().paused = false
			get_tree().reload_current_scene()
		)
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_b_2_pressed() -> void:
	pass # Replace with function body or customize later.

func _on_b_3_pressed() -> void:
	var ui_container = get_child(0) as Control
	if is_instance_valid(ui_container):
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
			
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
# =========================================================================
func _set_buttons_mouse_filter(parent_node: Node, target_filter: Control.MouseFilter) -> void:
	for child in parent_node.get_children():
		if child is Button:
			child.mouse_filter = target_filter
		if child.get_child_count() > 0:
			_set_buttons_mouse_filter(child, target_filter)
