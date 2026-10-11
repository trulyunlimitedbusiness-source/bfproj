extends CanvasLayer

@onready var inv: Inv = preload("res://upgrade system/inventory.tres")

# 🛰️ TRACKER DIRECTORIES
@onready var left_melee_grid: Control = $invctrl/GridContainer
@onready var storage_grid: Control = $invctrl/StorageGrid
@onready var passive_grid: Control = $invctrl/passivegrid
@onready var passive_storage: Control = $invctrl/passivestorage
@onready var left_hand_hud: VBoxContainer = get_node_or_null("../uiLayer/GameplayDeckHUD/LeftHandHUD")
@onready var right_hand_hud: VBoxContainer = get_node_or_null("../uiLayer/GameplayDeckHUD/RightHandHUD")
@onready var card_click_sound: AudioStreamPlayer = $click
const MOD_TEX = preload("res://upgrade system/sprites/descbox.png")
const ATK_TEX = preload("res://upgrade system/sprites/descbox2.png")
const PAS_TEX = preload("res://upgrade system/sprites/passivedesc.png")
const MOD_FONT_COLOR = Color("f5bfbc")
const MOD_OUTLINE_COLOR = Color("240202")
const ATK_FONT_COLOR = Color("420909")
const ATK_OUTLINE_COLOR = Color("ffcaca")
const PAS_FONT_COLOR = Color(0.196, 0.259, 0.09, 1.0)
const PAS_OUTLINE_COLOR = Color(0.889, 0.986, 0.744, 1.0)
var button_1_tween: Tween = null
var button_2_tween: Tween = null
@onready var red_left: NinePatchRect = $invctrl/Control/NinePatchRect
@onready var red_right: NinePatchRect = $invctrl/Control/NinePatchRect2

# PAGE 2 (Green Panels - Sitting behind Page 1)
@onready var green_left: NinePatchRect = $invctrl/Control/NinePatchRect3
@onready var green_right: NinePatchRect = $invctrl/Control/NinePatchRect4
var page_flip_tween: Tween = null

var slots: Array = []
var is_open = false
var active_drag_source_index: int = -1
var current_hovered_slot_index: int = -1
var _pop_tween: Tween
var _last_hovered_idx: int = -1

# =========================================================================
# 📐 PALETTE CONFIGURATOR SCALERS
# =========================================================================
const SELECTED_SIZE: float = 128.0  
const DROPPED_SIZE: float = 100.0   

# 🎯 DYNAMIC PIVOT OFFSETS
@onready var mouse_top_center_offset: Vector2 = Vector2(SELECTED_SIZE / 2.0, 0.0)
# =========================================================================
# 🎛️ EXPOSED PIXEL-ART DECK CONTROLLERS
# =========================================================================
@export var storage_overlap_gap: int = -35 

# 🎯 RIGHT SHIFT LIMIT: Controls how wide cards open on a mouse hover
@export var storage_shift_amount: float = 40.0 

# 🎯 NEW LEFT SHIFT LIMIT (THE HOLE-CLOSER TUNER):
# Controls exactly how many pixels cards on the right slide LEFT to fill the 
# empty space when a card is pulled out of your hand!
@export var storage_remove_shift_amount: float = 65.0

# 💾 VISUAL JUICE PROPERTIES
var floating_preview_card: TextureRect = null
var current_dragged_item_resource: Resource = null
var last_mouse_position: Vector2 = Vector2.ZERO
var master_swap_tween: Tween = null

@export var BASE_DECK_SPEED_DELAY: float = 0.10

var left_hand_index_head: int = 0
var right_hand_index_head: int = 36

var left_hand_cooldown: float = 0.0
var right_hand_cooldown: float = 0.0

# 🔓 THE ONE-CLICK AUTOMATION HEADERS
var is_left_hand_streaming: bool = false
var is_right_hand_streaming: bool = false

# ⚡ ONE-SHOT MULTIPLIER SAFETY SWAP
var left_modifier_multiplier_primed: bool = false
var right_modifier_multiplier_primed: bool = false

var left_size_multiplier_primed: bool = false
var right_size_multiplier_primed: bool = false
@export var deck_speed_multiplier: float = 1.0 # Base default speed multiplier
@export var PADDING_SKIPPING_DELAY: float = 0.01 # Snap fast through padding blocks!
@export var EMPTY_SLOT_SKIPPING_DELAY: float = 0.005 
@onready var description_popup: NinePatchRect = $DescriptionPopup
@onready var description_label: Label = $DescriptionPopup/DescriptionLabel
var active_flight_targets: Dictionary = {}
var upgrade_mult = 1.5
func _ready() -> void:
	_register_slots()
	
	if inv != null and inv.items.size() != 160:
		inv.items.resize(160)

	# 🚀 FORCE PAGE 1 CONTAINERS ACTIVE IMMEDIATELY ON STARTUP
	_set_inventory_containers_active(true)

	if is_instance_valid(red_left): red_left.visible = true
	if is_instance_valid(green_right): green_right.visible = false

	print("Inventory UI Ready. Page 1 forced active on startup.")
	update_slots()
	_set_inventory_containers_active(true)
	$invctrl/Control/TextureButton2.visible = false
	if is_instance_valid(description_popup):
		description_popup.visible = false
		description_popup.scale = Vector2.ONE
		description_popup.modulate.a = 1.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Register this node instance with your global singleton bridge
	globals.inventory = self
	
	# Gather the visual panel child nodes from your grid containers safely
	var melee_children = left_melee_grid.get_children() if is_instance_valid(left_melee_grid) else []
	var storage_children = storage_grid.get_children() if is_instance_valid(storage_grid) else []
	
	slots.clear()
	
	# Add melee slots first (Slots 0 to 71)
	for slot in melee_children:
		if is_instance_valid(slot):
			slots.append(slot)
			
	# Add storage slots sequentially until the strict 160 total limit is met
	for slot in storage_children:
		if is_instance_valid(slot) and slots.size() < 160:
			slots.append(slot)
			
	# Hide any extra visual slots in the scene that exceed the 160 inventory limit
	for i in range(160, storage_children.size()):
		if is_instance_valid(storage_children[i]):
			storage_children[i].visible = false

	print("🛠️ INVENTORY UI: Validated and locked slots to: ", slots.size())

	# Ensure inventory resource matches exactly 160 data addresses
	if is_instance_valid(inv):
		if inv.items.size() != 160:
			inv.items.resize(160)
			print("📦 DATABASE FIXED: Resized inv.items array up to 160 addresses.")

	# Map clean, sequential index identities (0 to 159) onto every active panel cell
	for i in range(slots.size()):
		var slot_node = slots[i]
		if is_instance_valid(slot_node):
			slot_node.slot_index = i
			slot_node.parent_ui_manager = self
			
	_initialize_floating_preview_layer()
	update_slots()
	close()
func _register_slots() -> void:
	slots.clear()
	
	# Gather Red page slots
	var melee_children = left_melee_grid.get_children() if is_instance_valid(left_melee_grid) else []
	for slot in melee_children:
		if is_instance_valid(slot) and slots.size() < 160:
			slots.append(slot)
			
	# Gather Green page / storage slots up to 160 total
	var storage_children = storage_grid.get_children() if is_instance_valid(storage_grid) else []
	for slot in storage_children:
		if is_instance_valid(slot) and slots.size() < 160:
			slots.append(slot)

	print("🛠️ INVENTORY UI: Final locked slots count = ", slots.size())
func _initialize_floating_preview_layer() -> void:
	floating_preview_card = TextureRect.new()
	floating_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_preview_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floating_preview_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floating_preview_card.stretch_mode = TextureRect.STRETCH_SCALE
	floating_preview_card.visible = false
	floating_preview_card.custom_minimum_size = Vector2(SELECTED_SIZE, SELECTED_SIZE)
	floating_preview_card.size = Vector2(SELECTED_SIZE, SELECTED_SIZE)
	floating_preview_card.pivot_offset = mouse_top_center_offset
	add_child(floating_preview_card)
func _process(delta: float) -> void:
	# 🎴 HOVER DESCRIPTION TICK
	if is_open:
		var hovered_idx = get_slot_index_under_mouse()
		_update_hover_description(hovered_idx)
	else:
		hide_description()

	# 🎒 INVENTORY WINDOW TOGGLE KEYS
	if Input.is_action_just_pressed("inv_open"):
		if is_open: close()
		else: open()
		return
		
	if globals.is_dead:
		visible = false
		return

	# Hand cooldown clocks
	left_hand_cooldown -= delta
	right_hand_cooldown -= delta
	
	# =========================================================================
	# ⌨️ EXCLUSIVE DECK INPUT LISTENERS (GAMEPLAY ONLY)
	# =========================================================================
	if not is_open:
		var left_clicked: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if left_clicked:
			if not is_left_hand_streaming and not is_right_hand_streaming and left_hand_cooldown <= 0.0:
				is_left_hand_streaming = true
				left_hand_index_head = 0
				left_hand_cooldown = 0.0
				
		var right_clicked: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if right_clicked:
			if not is_left_hand_streaming and not is_right_hand_streaming and right_hand_cooldown <= 0.0:
				is_right_hand_streaming = true
				right_hand_index_head = 36
				right_hand_cooldown = 0.0

	# =========================================================================
	# 🚀 DECK STREAM ENGINE CORE AUTOMATION
	# =========================================================================
	var can_weapon_execute: bool = true
	if is_instance_valid(globals.torch) and "can_shoot" in globals.torch:
		can_weapon_execute = globals.torch.can_shoot

	if can_weapon_execute:
		if is_left_hand_streaming and left_hand_cooldown <= 0.0:
			_process_sequential_deck_step(true)
		if is_right_hand_streaming and right_hand_cooldown <= 0.0:
			_process_sequential_deck_step(false)

	if not is_open: 
		hide_description()
		return
	
	# =========================================================================
	# 🎴 DYNAMIC PALETTE SWINGING & DUAL-PAGE HOVER SHIFTER
	# =========================================================================
	if floating_preview_card and floating_preview_card.visible:
		var current_mouse_pos = get_viewport().get_mouse_position()
		floating_preview_card.global_position = current_mouse_pos - mouse_top_center_offset
		
		var mouse_velocity = current_mouse_pos.x - last_mouse_position.x
		last_mouse_position = current_mouse_pos
		
		var desired_tilt = clamp(mouse_velocity * 0.04, -0.45, 0.45)
		floating_preview_card.rotation = lerp(floating_preview_card.rotation, desired_tilt, 15.0 * delta)
		
		var hovered_idx = get_slot_index_under_mouse()
		_update_hover_description(hovered_idx)
		
		var slot_width: float = 100.0
		
		var start_s_idx = -1
		var end_s_idx = -1
		
		if hovered_idx >= 72 and hovered_idx < 92:
			start_s_idx = 72
			end_s_idx = 92 # Page 1 Active Storage Pool
		elif hovered_idx >= 140 and hovered_idx < 160:
			start_s_idx = 140
			end_s_idx = 160 # Page 2 Passive Storage Pool
			
		if start_s_idx != -1:
			for i in range(start_s_idx, end_s_idx):
				var slot_node = slots[i]
				if is_instance_valid(slot_node) and slot_node.visible:
					var card_visual_child = slot_node.get_node_or_null("CenterContainer")
					if is_instance_valid(card_visual_child):
						var target_x = 0.0
						
						if active_drag_source_index != -1:
							if active_drag_source_index < start_s_idx or active_drag_source_index >= end_s_idx:
								if i >= hovered_idx:
									target_x = slot_width
							else:
								if active_drag_source_index < hovered_idx:
									if i > active_drag_source_index and i <= hovered_idx:
										target_x = -slot_width
								elif active_drag_source_index > hovered_idx:
									if i >= hovered_idx and i < active_drag_source_index:
										target_x = slot_width
										
						card_visual_child.position.x = lerp(card_visual_child.position.x, target_x, 20.0 * delta)
	else:
		for i in range(slots.size()):
			if (i >= 72 and i < 92) or (i >= 140 and i < 160):
				var slot_node = slots[i]
				if is_instance_valid(slot_node):
					var card_visual_child = slot_node.get_node_or_null("CenterContainer")
					if is_instance_valid(card_visual_child):
						card_visual_child.position.x = lerp(card_visual_child.position.x, 0.0, 16.0 * delta)
func get_slot_index_under_mouse() -> int:
	var mouse_pos = get_viewport().get_mouse_position()
	
	for i in range(slots.size()):
		var slot_node = slots[i]
		# Only check slots that are currently visible and part of the active page view
		if is_instance_valid(slot_node) and slot_node.is_visible_in_tree():
			if slot_node.get_global_rect().has_point(mouse_pos):
				return i
				
	return -1
func _get_card_info_for_frame(f_id: int) -> Dictionary:
	match f_id:
		0:
			return {
				"title": "Sprint:",
				"body": "Player moves 1.5x\nfaster",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		1:
			return {
				"title": "Damage:",
				"body": "Increases damage by\n1.5x",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		2:
			return {
				"title": "Ranged:",
				"body": "Basic projectile\nattack, shoots narrow\nfireballs (25 damage)",
				"bg_texture": ATK_TEX,
				"font_color": ATK_FONT_COLOR,
				"outline_color": ATK_OUTLINE_COLOR
			}
		3:
			return {
				"title": "Melee:",
				"body": "70 degree melee torch\nswipe (25 damage)",
				"bg_texture": ATK_TEX,
				"font_color": ATK_FONT_COLOR,
				"outline_color": ATK_OUTLINE_COLOR
			}
		4:
			return {
				"title": "Projectile Velocity:",
				"body": "Projectiles travel\n1.5x faster",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		5:
			return {
				"title": "Accuracy:",
				"body": "Projectiles increase\nin accuracy by 15%",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		6:
			return {
				"title": "Cooling:",
				"body": "Torch overheats 15% less",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		7:
			return {
				"title": "Efficiency:",
				"body": "Torch takes 15% less\nfuel",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		8:
			return {
				"title": "Multishot:",
				"body": "Shoots 1 more\nprojectile",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		9:
			return {
				"title": "Player Knockback:",
				"body": "Player knockback is\nincreased by 1.5x",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		10:
			return {
				"title": "Slide:",
				"body": "Slippery slide\n(increases by 1.5x)",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		11:
			return {
				"title": "Attack Size:",
				"body": "Makes attacks\nlarger by 1.5x",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		12:
			return {
				"title": "Deck Speed:",
				"body": "Both hands play\n1.5x faster",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		13:
			return {
				"title": "Enemy Knockback:",
				"body": "Enemy knockback is\nincreased by 1.5x",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}
		18:
			return {
				"title": "Everything All Of The Time:",
				"body": "Every modifier\nupgraded by 50%",
				"bg_texture": PAS_TEX,
				"font_color": PAS_FONT_COLOR,
				"outline_color": PAS_OUTLINE_COLOR
			}
		_:
			print("WARNING: Unknown card_sprite_frame ID: ", f_id)
			return {
				"title": "",
				"body": "",
				"bg_texture": MOD_TEX,
				"font_color": MOD_FONT_COLOR,
				"outline_color": MOD_OUTLINE_COLOR
			}


func _update_hover_description(hovered_idx: int) -> void:
	if active_drag_source_index != -1 or hovered_idx == -1:
		if _last_hovered_idx != -1:
			_last_hovered_idx = -1
			hide_description()
		return

	if hovered_idx < inv.items.size():
		var card = inv.items[hovered_idx]
		
		if not is_instance_valid(card) and hovered_idx < slots.size():
			var slot_node = slots[hovered_idx]
			if is_instance_valid(slot_node):
				if "item" in slot_node:
					card = slot_node.item
				elif "card" in slot_node:
					card = slot_node.card

		if is_instance_valid(card):
			var f_id: int = -1
			if "card_sprite_frame" in card:
				f_id = card.card_sprite_frame
			elif card.has_method("get") and card.get("card_sprite_frame") != null:
				f_id = card.get("card_sprite_frame")
				
			var info: Dictionary = _get_card_info_for_frame(f_id)
			
			if info["title"] != "" or info["body"] != "":
				var slot_changed: bool = (hovered_idx != _last_hovered_idx)
				_last_hovered_idx = hovered_idx
				
				show_description(
					info["title"],
					info["body"],
					info.get("bg_texture"),
					info.get("font_color"),
					info.get("outline_color"),
					slot_changed
				)
				
				if is_instance_valid(description_popup):
					var mouse_pos = get_viewport().get_mouse_position()
					description_popup.global_position = mouse_pos + Vector2(16.0, 16.0)
				return

	if _last_hovered_idx != -1:
		_last_hovered_idx = -1
		hide_description()


func show_description(
	title_text: String,
	body_text: String,
	custom_texture: Texture2D = null,
	font_color: Color = Color.WHITE,
	outline_color: Color = Color.BLACK,
	force_retween: bool = false
) -> void:
	if not is_instance_valid(description_popup):
		return
		
	if is_instance_valid(description_label):
		description_label.text = title_text + "\n\n" + body_text
		
		if description_label.label_settings:
			# Ensure label_settings is uniquely owned by this node once
			if not description_label.label_settings.resource_local_to_scene:
				description_label.label_settings = description_label.label_settings.duplicate()
				description_label.label_settings.resource_local_to_scene = true
			
			description_label.label_settings.font_color = font_color
			description_label.label_settings.outline_color = outline_color
			if description_label.label_settings.outline_size == 0:
				description_label.label_settings.outline_size = 4
		else:
			description_label.add_theme_color_override("font_color", font_color)
			description_label.add_theme_color_override("font_outline_color", outline_color)
			description_label.add_theme_constant_override("outline_size", 4)

	if description_popup is NinePatchRect and custom_texture != null:
		description_popup.texture = custom_texture

	if not description_popup.visible or force_retween:
		description_popup.visible = true
		
		description_popup.scale = Vector2(0.3, 0.3)
		description_popup.modulate.a = 0.0
		description_popup.rotation_degrees = -8.0

		if _pop_tween and _pop_tween.is_running():
			_pop_tween.kill()

		_pop_tween = create_tween().set_parallel(true)
		
		_pop_tween.tween_property(description_popup, "scale", Vector2.ONE, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
		_pop_tween.tween_property(description_popup, "modulate:a", 1.0, 0.12)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		_pop_tween.tween_property(description_popup, "rotation_degrees", 0.0, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_description() -> void:
	if not is_instance_valid(description_popup) or not description_popup.visible:
		return

	if _pop_tween and _pop_tween.is_running():
		_pop_tween.kill()

	_pop_tween = create_tween().set_parallel(true)

	_pop_tween.tween_property(description_popup, "scale", Vector2(0.3, 0.3), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_pop_tween.tween_property(description_popup, "modulate:a", 0.0, 0.1)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	_pop_tween.tween_property(description_popup, "rotation_degrees", -10.0, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_pop_tween.chain().tween_callback(func():
		description_popup.visible = false
		description_popup.scale = Vector2.ONE
		description_popup.modulate.a = 1.0
		description_popup.rotation_degrees = 0.0
	)
func _process_sequential_deck_step(is_left_hand: bool) -> void:
	if inv == null: return

	# 1. Block step execution if current slot's fire rate delay is still active
	if is_left_hand and left_hand_cooldown > 0.0: return
	if not is_left_hand and right_hand_cooldown > 0.0: return

	# Fuel Safety Check
	if is_instance_valid(globals.torch) and "current_fuel" in globals.torch:
		if globals.torch.current_fuel <= 0.0:
			if is_left_hand: is_left_hand_streaming = false
			else: is_right_hand_streaming = false
			update_slots()
			print("⛽ STREAM HALTED: Torch is out of fuel!")
			return

	var start_slot = 0 if is_left_hand else 36
	var end_slot = 35 if is_left_hand else 71
	var current_head = left_hand_index_head if is_left_hand else right_hand_index_head

	if current_head < start_slot or current_head > end_slot:
		current_head = start_slot
		_terminate_active_hand_stream(is_left_hand, start_slot)
		return

	# Fetch active card
	var card_to_play: InvItem = null
	if current_head < inv.items.size():
		card_to_play = inv.items[current_head]

	var current_step_cooldown: float = EMPTY_SLOT_SKIPPING_DELAY if "EMPTY_SLOT_SKIPPING_DELAY" in self else 0.01

	# =========================================================================
	# 🎭 SEQUENTIAL STEP EXECUTION
	# =========================================================================
	if card_to_play != null:
		# 🎴 1. Trigger Visual Juice Proc for THIS slot only
		var target_container = globals.left_hand_hud_container if is_left_hand else globals.right_hand_hud_container
		if is_instance_valid(target_container):
			var relative_idx = current_head - start_slot
			var hud_children = target_container.get_children()
			if relative_idx >= 0 and relative_idx < hud_children.size():
				_play_palette_card_proc(hud_children[relative_idx])

		# 2. Extract attack method
		var target_method: String = ""
		if "attack_method_name" in card_to_play and card_to_play.attack_method_name != "":
			target_method = card_to_play.attack_method_name
		else:
			target_method = card_to_play.get("attack_method_name") if card_to_play.get("attack_method_name") != null else ""
		
		if target_method == "":
			if card_to_play.card_sprite_frame == 2: target_method = "shoot"
			elif card_to_play.card_sprite_frame == 3: target_method = "execute_melee_swipe_action"

		current_step_cooldown = PADDING_SKIPPING_DELAY if "PADDING_SKIPPING_DELAY" in self else 0.03

		# 3. Apply modifier/passive impact
		_apply_single_card_impact(card_to_play)

		# 4. Fire weapon action and apply full deck fire rate cooldown
		if target_method != "":
			current_step_cooldown = BASE_DECK_SPEED_DELAY
			
			if is_instance_valid(globals.torch):
				if globals.torch.has_method("force_interrupt_current_attack_state"):
					globals.torch.force_interrupt_current_attack_state()
				if globals.torch.has_method(target_method):
					globals.torch.call(target_method)
	else:
		current_step_cooldown = EMPTY_SLOT_SKIPPING_DELAY if "EMPTY_SLOT_SKIPPING_DELAY" in self else 0.01

	# Set delay timer so _process() waits before running the next index step
	if is_left_hand:
		left_hand_cooldown = current_step_cooldown
	else:
		right_hand_cooldown = current_step_cooldown

	# Advance pointer by 1 index
	current_head += 1

	# Deck wrap-around reset check
	if current_head > end_slot:
		current_head = start_slot
		if is_left_hand:
			is_left_hand_streaming = false
			left_hand_index_head = current_head
		else:
			is_right_hand_streaming = false
			right_hand_index_head = current_head
		update_slots()
		return

	# Store current head pointer
	if is_left_hand:
		left_hand_index_head = current_head
	else:
		right_hand_index_head = current_head
func _terminate_active_hand_stream(is_left_hand: bool, fallback_start_slot: int) -> void:
	if is_left_hand:
		is_left_hand_streaming = false
		left_hand_index_head = fallback_start_slot
		left_hand_cooldown = 0.0
	else:
		is_right_hand_streaming = false
		right_hand_index_head = fallback_start_slot
		right_hand_cooldown = 0.0
	update_slots()
func apply_passive_card_impact() -> void:
	# Iterate exclusively across Page 2's Passive Grid slots (92 to 139)
	for i in range(92, 140):
		var passive_item: InvItem = inv.items[i] if i < inv.items.size() else null
		if passive_item == null:
			continue
			
		var f_id: int = passive_item.card_sprite_frame
		
		# 🎴 PASSIVE CARD IMPACT MAPPING BY ANIMATED SPRITE FRAME
		if f_id == 18: # Everythingallthetime
			upgrade_mult *= 1.5
func _apply_single_card_impact(equipped_card: InvItem) -> void:
	if not is_instance_valid(equipped_card): return
	
	var f_id = equipped_card.card_sprite_frame
	
	if f_id == 0:
		if is_instance_valid(globals.player):
			globals.player.SPEED *= upgrade_mult
			globals.player.STEP_DELAY /= upgrade_mult
			
	elif f_id == 1:
		if is_instance_valid(globals.torch):
			globals.torch.SWIPE_DAMAGE *= upgrade_mult
			globals.torch.damage *= upgrade_mult*1.2
			
	elif f_id == 4:
		if is_instance_valid(globals.torch):
			globals.torch.speed *= upgrade_mult/1.1
			globals.torch.max_range *= upgrade_mult
			
	elif f_id == 5:
		if is_instance_valid(globals.torch):
			globals.torch.accuracy_spread_degrees /= upgrade_mult
			
	elif f_id == 6:
		if is_instance_valid(globals.torch):
			globals.torch.overheat_cost /= upgrade_mult
			
	elif f_id == 7:
		if is_instance_valid(globals.torch):
			globals.torch.fuel_cost /= upgrade_mult*1.1
			
	elif f_id == 8:
		if is_instance_valid(globals.torch):
			globals.torch.shoot_count += 1
			
	elif f_id == 9:
		if is_instance_valid(globals.player):
			globals.player.RECOIL_FORCE *= upgrade_mult*1.2
			
	elif f_id == 10:
		if is_instance_valid(globals.player):
			globals.player.slipperiness += 0.50
			globals.player.slipperiness *= upgrade_mult*1.2
			globals.player.slide_speed *= upgrade_mult
			globals.player.FRICTION /= upgrade_mult
			
	elif f_id == 11:
		if is_instance_valid(globals.torch):
			# Set up our absolute resting ceiling cap and our dramatic overshoot peak
			var resting_modifier_scale = Vector2(upgrade_mult/1.1, upgrade_mult/1.1)
			var explosive_overshoot_peak = Vector2(upgrade_mult, upgrade_mult)
			
			# Keep your backend projectile mathematical values locked to their ceiling caps
			globals.torch.projectile_size = Vector2(upgrade_mult/1.1, upgrade_mult/1.1)
			
			# =========================================================================
			# 🪀 MULTI-STAGE SHOCKWAVE TWEEN CHAIN
			# 💡 FIXED: Split into a chain! First it explodes outward to a giant size, 
			# then it uses TRANS_ELASTIC to snap back and wobble aggressively like a spring!
			# =========================================================================
			var wobble_tween = globals.torch.create_tween()
			
			# STAGE 1: Explosive outward expansion blast (Crisp and rapid)
			wobble_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			wobble_tween.tween_property(globals.torch, "scale", explosive_overshoot_peak, 0.12)
			
			# STAGE 2: The Snap-Back Wobble (Chained automatically to ripple back home)
			wobble_tween.chain().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			wobble_tween.tween_property(globals.torch, "scale", resting_modifier_scale, 0.55)
			globals.torch.damage *= upgrade_mult/1.3
			globals.torch.SWIPE_DAMAGE *= upgrade_mult/1.3
	elif f_id == 12:
		if is_instance_valid(globals.torch):
			globals.torch.fire_rate /= upgrade_mult/1.1
			BASE_DECK_SPEED_DELAY /= upgrade_mult/1.1
			globals.torch.fuel_cost /= upgrade_mult/1.1
			globals.torch.overheat_cost /= upgrade_mult/1.1
			PADDING_SKIPPING_DELAY /= upgrade_mult/1.1
			EMPTY_SLOT_SKIPPING_DELAY /= upgrade_mult/1.1
			globals.torch.active_melee_attack_duration /= upgrade_mult/1.1
			globals.torch.swing_speed_ratio /= upgrade_mult/1.1
	elif f_id == 13:
		if is_instance_valid(globals.torch):
			globals.torch.KNOCKBACK_FORCE *= upgrade_mult
			globals.torch.KNOCKBACK_FRICTION /= upgrade_mult
			globals.torch.HIT_STOP_DURATION *= upgrade_mult
func drop_card_into_slot(from_idx: int, to_idx: int) -> void:
	print("🎯 DROP CALLED: from_idx=", from_idx, " to_idx=", to_idx, " | slots.size()=", slots.size())
	
	var max_limit = min(slots.size(), inv.items.size())
	if from_idx < 0 or to_idx < 0 or from_idx >= max_limit or to_idx >= max_limit:
		print("❌ REJECTED: Out of bounds! max_limit=", max_limit)
		active_drag_source_index = -1
		current_dragged_item_resource = null
		if floating_preview_card:
			floating_preview_card.visible = false
		update_slots()
		return

	var source_item = current_dragged_item_resource if "current_dragged_item_resource" in self else null
	if source_item == null:
		source_item = inv.items[from_idx] 

	if source_item != null:
		var target_is_passive = (to_idx >= 92 and to_idx < max_limit)
		print("🔍 Zone check: item is_passive=", source_item.is_passive, " | target_is_passive=", target_is_passive)
		if source_item.is_passive != target_is_passive:
			print("❌ REJECTED: Zone mismatch (Active vs Passive zone violation)")
			active_flight_targets.erase(from_idx)
			active_drag_source_index = -1
			current_dragged_item_resource = null
			if floating_preview_card:
				floating_preview_card.visible = false
			update_slots()
			return

	print("✅ DROP SUCCESSFUL: Proceeding with swap animation/data commit.")
	# (Rest of your existing function code below...)

	var actual_to_idx = to_idx

	var target_slot_node = slots[actual_to_idx] if actual_to_idx < slots.size() else null
	var origin_slot_node = slots[from_idx] if from_idx < slots.size() else null
	
	if not is_instance_valid(origin_slot_node) or not is_instance_valid(target_slot_node):
		_commit_slot_data_swap(from_idx, actual_to_idx, source_item)
		active_flight_targets.erase(from_idx)
		active_flight_targets.erase(actual_to_idx)
		active_drag_source_index = -1
		current_dragged_item_resource = null
		update_slots()
		return

	active_flight_targets[from_idx] = true
	active_flight_targets[actual_to_idx] = true

	if origin_slot_node.has_node("CenterContainer"):
		origin_slot_node.get_node("CenterContainer").visible = false

	var target_pos = target_slot_node.global_position
	if floating_preview_card:
		floating_preview_card.pivot_offset = Vector2.ZERO

	# =========================================================================
	# ✈️ TWEEN SWAP ANIMATION
	# =========================================================================
	master_swap_tween = create_tween()
	master_swap_tween.set_parallel(true)
	master_swap_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if floating_preview_card:
		master_swap_tween.tween_property(floating_preview_card, "global_position", target_pos, 0.15)
		master_swap_tween.tween_property(floating_preview_card, "scale", Vector2.ONE, 0.15)
		master_swap_tween.tween_property(floating_preview_card, "rotation", 0.0, 0.10)

	master_swap_tween.chain().tween_callback(func():
		_commit_slot_data_swap(from_idx, actual_to_idx, source_item)
		
		if floating_preview_card:
			floating_preview_card.visible = false

		active_flight_targets.erase(from_idx)
		active_flight_targets.erase(actual_to_idx)
		active_drag_source_index = -1
		current_dragged_item_resource = null

		# Reset visual horizontal hover shifts in storage slots
		for i in range(slots.size()):
			if (i >= 72 and i < 92) or (i >= 140 and i < 160):
				var s_node = slots[i]
				if is_instance_valid(s_node):
					var child = s_node.get_node_or_null("CenterContainer")
					if is_instance_valid(child):
						child.position.x = 0.0

		var dropped_item = inv.items[actual_to_idx]
		_apply_single_card_impact(dropped_item)
				
		apply_passive_card_impact()
		update_slots()
	)
func update_slots() -> void:
	if inv == null or inv.items.is_empty():
		return
		
	# Loop through slots and update their data safely without recursion triggers
	for i in range(min(slots.size(), inv.items.size())):
		var slot = slots[i]
		if is_instance_valid(slot):
			if slot.has_method("update"):
				slot.update(inv.items[i])
			else:
				var item = inv.items[i]
				var item_visuals = slot.get_node_or_null("CenterContainer/Panel/item_display")
				if is_instance_valid(item_visuals):
					if item != null and item.texture != null:
						item_visuals.texture = item.texture
						item_visuals.visible = true
					else:
						item_visuals.texture = null
						item_visuals.visible = false

	# =========================================================================
	# 📊 GLOBAL STAT DEFAULT ROOTS RESTORATION
	# =========================================================================
	if is_instance_valid(globals.torch):
		globals.torch.SWIPE_DAMAGE = 18.0
		globals.torch.damage = 25.0
		globals.torch.speed = 175.0
		globals.torch.max_range = 210.0
		globals.torch.accuracy_spread_degrees = 6.5
		globals.torch.fuel_cost = 1.5
		globals.torch.overheat_cost = 2.0
		globals.torch.shoot_count = 1
		globals.torch.fire_rate = 0.40
		globals.player.SPEED = 120.0
		globals.player.RECOIL_FORCE = 80.0
		globals.player.STEP_DELAY = 0.35
		globals.player.slipperiness = 0.0
		globals.player.slide_speed = 0.0
		globals.player.FRICTION = 1500.0
		BASE_DECK_SPEED_DELAY = 0.10
		PADDING_SKIPPING_DELAY = 0.01
		EMPTY_SLOT_SKIPPING_DELAY = 0.005
		globals.torch.swing_speed_ratio = 0.45
		globals.torch.active_melee_attack_duration = 0.45
		globals.torch.projectile_size = Vector2(1.0, 1.0)
		globals.torch.KNOCKBACK_FORCE = 10.0
		globals.torch.KNOCKBACK_FRICTION = 5.0
		globals.torch.HIT_STOP_DURATION = 0.1
		upgrade_mult = 1.5
		
		var resting_baseline_scale = Vector2(1.0, 1.0)
		var elastic_undershoot_peak = Vector2(0.7, 0.7)
		
		if globals.torch.scale.x > 1.01 or globals.torch.scale.y > 1.01:
			var reset_tween = globals.torch.create_tween()
			reset_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			reset_tween.tween_property(globals.torch, "scale", elastic_undershoot_peak, 0.10)
			reset_tween.chain().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			reset_tween.tween_property(globals.torch, "scale", resting_baseline_scale, 0.50)
			
			var torch_sprite = globals.torch.get_node_or_null("AnimatedSprite2D")
			if is_instance_valid(torch_sprite):
				var sprite_tween = torch_sprite.create_tween()
				sprite_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				sprite_tween.tween_property(torch_sprite, "scale", elastic_undershoot_peak, 0.10)
				sprite_tween.chain().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				sprite_tween.tween_property(torch_sprite, "scale", Vector2.ONE, 0.50)
		else:
			globals.torch.scale = resting_baseline_scale
			var torch_sprite = globals.torch.get_node_or_null("AnimatedSprite2D")
			if is_instance_valid(torch_sprite):
				torch_sprite.scale = Vector2.ONE
		
		if "deck_speed_multiplier" in self:
			self.deck_speed_multiplier = 1.0
			
		self.BASE_DECK_SPEED_DELAY = globals.torch.fire_rate if "fire_rate" in globals.torch else 0.50
		
	if is_instance_valid(globals.extinguish_station) and "tsprite" in globals.extinguish_station:
		if is_instance_valid(globals.extinguish_station.tsprite):
			globals.extinguish_station.tsprite.scale = Vector2(0.685, 0.685)
			
	if is_instance_valid(globals.campfire) and "tsprite" in globals.campfire:
		if is_instance_valid(globals.campfire.tsprite):
			globals.campfire.tsprite.scale = Vector2(0.862, 0.867)

	# REFRESH LEFT HAND HUD (Slots 0 to 11 matched 1:1)
	if is_instance_valid(globals.left_hand_hud_container):
		var hud_slots = globals.left_hand_hud_container.get_children()
		for i in range(12):
			if i < hud_slots.size():
				var hud_slot_cell = hud_slots[i]
				var backend_item = inv.items[i]
				
				if is_instance_valid(hud_slot_cell):
					if hud_slot_cell.has_method("update"):
						hud_slot_cell.update(backend_item)
					elif "texture" in hud_slot_cell:
						hud_slot_cell.texture = backend_item.texture if backend_item != null else null
					elif hud_slot_cell.has_node("TextureRect"):
						var inner_tex = hud_slot_cell.get_node("TextureRect") as TextureRect
						if is_instance_valid(inner_tex):
							inner_tex.texture = backend_item.texture if backend_item != null else null

	# REFRESH RIGHT HAND HUD (Slots 36 to 47 matched 1:1)
	if is_instance_valid(globals.right_hand_hud_container):
		var hud_slots = globals.right_hand_hud_container.get_children()
		for i in range(12):
			if i < hud_slots.size():
				var hud_slot_cell = hud_slots[i]
				var backend_item = inv.items[36 + i]
				
				if is_instance_valid(hud_slot_cell):
					if hud_slot_cell.has_method("update"):
						hud_slot_cell.update(backend_item)
					elif "texture" in hud_slot_cell:
						hud_slot_cell.texture = backend_item.texture if backend_item != null else null
					elif hud_slot_cell.has_node("TextureRect"):
						var inner_tex = hud_slot_cell.get_node("TextureRect") as TextureRect
						if is_instance_valid(inner_tex):
							inner_tex.texture = backend_item.texture if backend_item != null else null
func open() -> void:
	$Cardflutter.pitch_scale = randf_range(0.75, 1.25)
	$Cardflutter.play()
	is_open = true
	visible = true
	
	if is_instance_valid(globals.player):
		globals.player.can_move = false
	if is_instance_valid(globals.torch):
		globals.torch.can_shoot = false
		
	last_mouse_position = get_viewport().get_mouse_position()
	
	if is_instance_valid($invctrl):
		# Align pivot precisely to screen center
		var screen_center = get_viewport().get_visible_rect().size / 2.0
		$invctrl.pivot_offset = screen_center - $invctrl.global_position
		
		# Set initial scale & opacity
		$invctrl.scale = Vector2(0.3, 0.3)
		$invctrl.modulate.a = 0.0
		
		var open_tween = create_tween().set_parallel(true)
		
		# Smooth pop-in animation
		open_tween.tween_property($invctrl, "scale", Vector2.ONE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
		open_tween.tween_property($invctrl, "modulate:a", 1.0, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
		# Reset pivot so drag math remains 1:1 on slots
		open_tween.chain().tween_callback(func():
			$invctrl.pivot_offset = Vector2.ZERO
			$invctrl.scale = Vector2.ONE
		)

func close() -> void:
	$Cardflip.pitch_scale = randf_range(0.75, 1.25)
	$Cardflip.play()
	
	if is_instance_valid(description_popup):
		description_popup.visible = false
		
	if is_instance_valid($invctrl):
		var screen_center = get_viewport().get_visible_rect().size / 2.0
		$invctrl.pivot_offset = screen_center - $invctrl.global_position
		
		# Sequence: slight stretch outward first, then snap shut
		var close_tween = create_tween()
			
		# 2. Strong horizontal collapse shut to 0 scale
		close_tween.tween_property($invctrl, "scale:x", 0.0, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			
		# Parallel fade out running alongside step 2
		var fade_tween = create_tween()
		fade_tween.tween_property($invctrl, "modulate:a", 0.0, 0.18)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			
		close_tween.tween_callback(func():
			is_open = false
			visible = false
			# Reset transform properties for the next open
			$invctrl.pivot_offset = Vector2.ZERO
			$invctrl.scale = Vector2.ONE
			$invctrl.modulate.a = 1.0
			
			if is_instance_valid(globals.player):
				globals.player.can_move = true
			if is_instance_valid(globals.torch):
				globals.torch.can_shoot = true
		)

func _commit_slot_data_swap(from_idx: int, to_idx: int, source_item: Resource) -> void:
	var target_item = inv.items[to_idx]

	# Handle storage array re-indexing without triggering premature visual packs
	if from_idx >= 72 and to_idx >= 72:
		var storage_items: Array = []
		for i in range(72, inv.items.size()):
			if i != from_idx and inv.items[i] != null:
				storage_items.append(inv.items[i])
		
		var insert_pos = clamp(to_idx - 72, 0, storage_items.size())
		storage_items.insert(insert_pos, source_item)
		
		for i in range(72, inv.items.size()):
			var rel_i = i - 72
			if rel_i < storage_items.size():
				inv.items[i] = storage_items[rel_i]
			else:
				inv.items[i] = null
	else:
		# Direct index swap for Hand <-> Storage or Hand <-> Hand
		inv.items[to_idx] = source_item
		inv.items[from_idx] = target_item
func _pack_storage_items() -> void:
	_pack_range(72, 92)   # Active Storage Pool (72-91)
	_pack_range(140, 160) # Passive Storage Pool (140-159)

func _pack_range(start_idx: int, end_idx: int) -> void:
	if inv == null or inv.items.size() < end_idx:
		return
		
	var non_empty: Array[InvItem] = []
	for i in range(start_idx, end_idx):
		if inv.items[i] != null:
			non_empty.append(inv.items[i])
			inv.items[i] = null
			
	for i in range(non_empty.size()):
		inv.items[start_idx + i] = non_empty[i]
func _play_palette_card_proc(hud_slot_cell: Node) -> void:
	if not is_instance_valid(hud_slot_cell):
		return

	# Resolve the target TextureRect node
	var target_visual: TextureRect = null
	if hud_slot_cell is TextureRect:
		target_visual = hud_slot_cell as TextureRect
	elif hud_slot_cell.has_node("TextureRect"):
		target_visual = hud_slot_cell.get_node("TextureRect") as TextureRect

	if not is_instance_valid(target_visual):
		return

	# Retrieve the InvItem resource assigned to this slot cell
	var item_data: InvItem = null
	if "item_data" in hud_slot_cell:
		item_data = hud_slot_cell.item_data
	elif hud_slot_cell.has_meta("item_data"):
		item_data = hud_slot_cell.get_meta("item_data")

	# Trigger the 2D coin-flip transition on the TextureRect
	play_card_flip(target_visual, item_data)
func play_card_flip(target_visual: TextureRect, item_data: InvItem) -> void:
	if not is_instance_valid(target_visual):
		return

	var visual_size = target_visual.size if target_visual.size != Vector2.ZERO else target_visual.custom_minimum_size
	target_visual.pivot_offset = visual_size / 2.0

	var existing_tween = target_visual.get_meta("proc_tween", null)
	if existing_tween and existing_tween.is_valid():
		existing_tween.kill()

	# Reset base transform state
	target_visual.scale = Vector2(1.0, 1.0)
	target_visual.flip_h = false

	var flip_tween = create_tween()
	target_visual.set_meta("proc_tween", flip_tween)

	# --- 1A. SHRINK TO MIDPOINT (X = 0.5) ---
	flip_tween.set_parallel(true)
	flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(target_visual, "scale:x", 0.5, 0.08)
	flip_tween.tween_property(target_visual, "scale:y", 1.1, 0.08)

	# --- MIDPOINT OF SHRINK: FLIP HORIZONTALLY ---
	flip_tween.chain().tween_callback(func():
		if is_instance_valid(target_visual):
			target_visual.flip_h = true
	)

	# --- 1B. FINISH SHRINKING TO EDGE (X = 0.0) ---
	flip_tween.chain().set_parallel(true)
	flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flip_tween.tween_property(target_visual, "scale:x", 0.0, 0.08)
	flip_tween.tween_property(target_visual, "scale:y", 1.2, 0.08)

	# --- SWAP TEXTURE AT ZERO WIDTH ---
	flip_tween.chain().tween_callback(func():
		if is_instance_valid(target_visual) and item_data != null:
			target_visual.texture = item_data.texture
	)

	# --- 2A. OVER-SCALE POP (EXPAND BEYOND 1.0) ---
	flip_tween.chain().set_parallel(true)
	flip_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Overshoot both X and Y to 1.35x scale for a juicy impact
	flip_tween.tween_property(target_visual, "scale", Vector2(1.35, 1.35), 0.12)

	# --- LANDING CALLBACK: UNFLIP BACK TO NORMAL ---
	flip_tween.chain().tween_callback(func():
		if is_instance_valid(target_visual):
			target_visual.flip_h = false
	)

	# --- 2B. SETTLE BACK TO NORMAL SIZE ---
	flip_tween.chain().set_parallel(true)
	flip_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.tween_property(target_visual, "scale", Vector2(1.0, 1.0), 0.08)
func lift_card_from_slot(source_idx: int, item: Resource) -> void:
	active_drag_source_index = source_idx
	current_dragged_item_resource = item
	
	if source_idx >= 0 and source_idx < inv.items.size():
		inv.items[source_idx] = null
	
	if is_instance_valid(card_click_sound):
		card_click_sound.pitch_scale = randf_range(0.8, 1.2)
		card_click_sound.volume_db = -8.0
		card_click_sound.play()
		
	if floating_preview_card and item:
		floating_preview_card.top_level = true
		floating_preview_card.z_index = 100
		
		# 🖱️ CRITICAL: Ignore mouse events so releases pass right through it!
		floating_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		
		floating_preview_card.texture = item.texture
		floating_preview_card.visible = true
		var current_mouse_pos = get_viewport().get_mouse_position()
		floating_preview_card.global_position = current_mouse_pos - mouse_top_center_offset
		last_mouse_position = current_mouse_pos
		floating_preview_card.scale = Vector2(0.4, 0.4)
		floating_preview_card.rotation = 0.0
		
		var pop_tween = create_tween()
		pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(floating_preview_card, "scale", Vector2.ONE, 0.12)
func _on_texture_button_pressed() -> void:
	# 🔴 FLIP FROM RED (PAGE 1) TO GREEN (PAGE 2)
	$click.pitch_scale = randf_range(0.88, 1.15)
	$click.play()
	
	# Hide both buttons during flip
	$invctrl/Control/TextureButton.visible = false
	$invctrl/Control/TextureButton2.visible = false
	
	# Instantly hide all card slots mid-flip
	_hide_all_inventory_containers()
	
	if page_flip_tween and page_flip_tween.is_valid():
		page_flip_tween.kill()

	page_flip_tween = create_tween()
	
	# 1. Base Layer Setup
	if is_instance_valid(red_left):
		red_left.visible = true
		red_left.scale.x = 1.0
		red_left.z_index = 0
		
	if is_instance_valid(green_right): 
		green_right.visible = true
		green_right.z_index = 0
		
	# 2. Fold Red Right into spine
	red_right.z_index = 1
	red_right.pivot_offset = Vector2(0, red_right.size.y / 2.0)
	
	page_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	page_flip_tween.tween_property(red_right, "scale:x", 0.0, 0.30)
	
	# 3. Midpoint Transition
	page_flip_tween.tween_callback(func():
		green_left.z_index = 2
		green_left.visible = true
		green_left.pivot_offset = Vector2(green_left.size.x, green_left.size.y / 2.0)
		green_left.scale.x = 0.0
		
		red_right.visible = false
		red_right.scale.x = 1.0
	)
	
	# Unfold Green Left
	page_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	page_flip_tween.tween_property(green_left, "scale:x", 1.0, 0.30)
	
	# 4. Finish: Show Green Page (Page 2) cards & Page 2 Button
	page_flip_tween.tween_callback(func():
		green_left.pivot_offset = Vector2.ZERO
		
		# 🟢 Show Page 2 (passives)
		_set_inventory_containers_active(false)
		
		if is_instance_valid(red_left): 
			red_left.visible = false
		
		# Reveal button to return to Red Page
		var btn2 = $invctrl/Control/TextureButton2
		btn2.visible = true
		btn2.z_index = 10
		$invctrl/Control/TextureButton.visible = false
	)


func _on_texture_button_2_pressed() -> void:
	# 🟢 FLIP FROM GREEN (PAGE 2) BACK TO RED (PAGE 1)
	$click.pitch_scale = randf_range(0.88, 1.15)
	$click.play()
	
	# Hide both buttons during flip
	$invctrl/Control/TextureButton.visible = false
	$invctrl/Control/TextureButton2.visible = false

	# Instantly hide all card slots mid-flip
	_hide_all_inventory_containers()

	if page_flip_tween and page_flip_tween.is_valid():
		page_flip_tween.kill()

	page_flip_tween = create_tween()
	
	# 1. Base Layer Setup
	if is_instance_valid(green_right):
		green_right.visible = true
		green_right.scale.x = 1.0
		green_right.z_index = 0
		
	if is_instance_valid(red_left): 
		red_left.visible = true
		red_left.z_index = 0
		
	# 2. Fold Green Left into spine
	green_left.z_index = 1
	green_left.pivot_offset = Vector2(green_left.size.x, green_left.size.y / 2.0)
	
	page_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	page_flip_tween.tween_property(green_left, "scale:x", 0.0, 0.30)
	
	# 3. Midpoint Transition
	page_flip_tween.tween_callback(func():
		red_right.z_index = 2
		red_right.visible = true
		red_right.pivot_offset = Vector2(0, red_right.size.y / 2.0)
		red_right.scale.x = 0.0
		
		green_left.visible = false
		green_left.scale.x = 1.0
	)
	
	# Unfold Red Right
	page_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	page_flip_tween.tween_property(red_right, "scale:x", 1.0, 0.30)
	
	# 4. Finish: Show Red Page (Page 1) cards & Page 1 Button
	page_flip_tween.tween_callback(func():
		red_right.pivot_offset = Vector2.ZERO
		
		# 🔴 Show Page 1 (melee & active storage)
		_set_inventory_containers_active(true)
		
		if is_instance_valid(green_right): 
			green_right.visible = false
		
		# Reveal button to flip to Green Page
		var btn1 = $invctrl/Control/TextureButton
		btn1.visible = true
		btn1.z_index = 10
		$invctrl/Control/TextureButton2.visible = false
	)


# Helper function to instantly turn off all slot visibility on both pages
func _hide_all_inventory_containers() -> void:
	var containers: Array[Control] = [left_melee_grid, storage_grid, passive_grid, passive_storage]
	for container in containers:
		if is_instance_valid(container):
			container.visible = false
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for slot in container.get_children():
				if slot is Control:
					slot.visible = false
					slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


# 2. Toggle active and passive container groups cleanly
func _set_inventory_containers_active(is_page_1_active: bool) -> void:
	# PAGE 1 CONTAINERS (Melee & Active Storage)
	var p1_containers: Array[Control] = []
	if is_instance_valid(left_melee_grid): p1_containers.append(left_melee_grid)
	if is_instance_valid(storage_grid): p1_containers.append(storage_grid)
	
	# PAGE 2 CONTAINERS (Passive Grid & Passive Storage)
	var p2_containers: Array[Control] = []
	if is_instance_valid(passive_grid): p2_containers.append(passive_grid)
	if is_instance_valid(passive_storage): p2_containers.append(passive_storage)

	# Apply visibility states
	_toggle_container_group(p1_containers, is_page_1_active)
	_toggle_container_group(p2_containers, not is_page_1_active)

	_reset_description_popup()
	update_slots()


# 3. Helper to toggle container visibility and their child slots
func _toggle_container_group(containers: Array[Control], active: bool) -> void:
	for container in containers:
		if not is_instance_valid(container):
			continue
			
		container.visible = active
		container.mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
		
		for slot in container.get_children():
			if slot is Control:
				slot.visible = active
				slot.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
				
				# Ensure internal card visuals inside slots match the parent state
				var card_visual = slot.get_node_or_null("CenterContainer")
				if is_instance_valid(card_visual):
					card_visual.visible = active
					card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_children_interactive_recursive(node: Node, active: bool) -> void:
	for child in node.get_children():
		if child is Control:
			child.visible = active
			if child is TextureRect or child is Label:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				child.mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
		_set_children_interactive_recursive(child, active)
func _reset_description_popup() -> void:
	if is_instance_valid(description_popup):
		description_popup.visible = false
	if is_instance_valid(description_label):
		description_label.text = ""


func _on_texture_button_mouse_entered() -> void:
	var btn = $invctrl/Control/TextureButton
	btn.pivot_offset = btn.size / 2.0
	
	if button_1_tween and button_1_tween.is_valid():
		button_1_tween.kill()
		
	button_1_tween = create_tween()
	button_1_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_1_tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.12)
func _on_texture_button_mouse_exited() -> void:
	var btn = $invctrl/Control/TextureButton
	
	if button_1_tween and button_1_tween.is_valid():
		button_1_tween.kill()
		
	button_1_tween = create_tween()
	button_1_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_1_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
func _on_texture_button_2_mouse_entered() -> void:
	var btn = $invctrl/Control/TextureButton2
	btn.pivot_offset = btn.size / 2.0
	
	if button_2_tween and button_2_tween.is_valid():
		button_2_tween.kill()
		
	button_2_tween = create_tween()
	button_2_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_2_tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.12)
func _on_texture_button_2_mouse_exited() -> void:
	var btn = $invctrl/Control/TextureButton2
	
	if button_2_tween and button_2_tween.is_valid():
		button_2_tween.kill()
		
	button_2_tween = create_tween()
	button_2_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_2_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
