extends CanvasLayer

# =========================================================================
# 🗃️ THE DATA STRUCTURE & EXPORTS REGISTER
# =========================================================================
class UpgradeCardData:
	var id: String = ""
	var name: String = "Unnamed Card"
	var type: String = "melee"       # "melee" or "range"
	var subtype: String = "attack"   # "attack" or "modifier"
	var frame_index: int = 0         # The index slice on your master SpriteFrames sheet
	var current_slot: int = -1       # -1 if sitting loose in the hand reservoir tray

# 🎨 EDITOR RESOURCE LINKERS
@export var master_sprite_frames: SpriteFrames
@export var inventory_panel_texture: Texture2D # Custom background image asset row

@onready var inventory_container: PanelContainer = $BackgroundDim/InventoryContainer
@onready var left_melee_grid: GridContainer = $BackgroundDim/InventoryContainer/GridSplitter/LeftMeleeGrid
@onready var right_range_grid: GridContainer = $BackgroundDim/InventoryContainer/GridSplitter/RightMeleeGrid
@onready var bottom_deck_reservoir: Control = $BackgroundDim/InventoryContainer/BottomDeckReservoir

# 💾 UNIFIED MASTER MEMORY POOLS
var left_melee_slots: Array[Button] = []
var right_range_slots: Array[Button] = []

# This single array list holds every single card the player has found or earned!
var collected_cards_data: Array[UpgradeCardData] = []
var active_selected_card_index: int = -1 # Tracks which loose hand item is clicked

# 🎛️ ADJUST THESE CALIBRATION CONSTANTS TO ALIGN OVER YOUR BACKGROUND GRID ART:
const GRID_COLUMN_GAP: int = 12   # 📐 Pixel space between column slots horizontally
const GRID_ROW_GAP: int = 8       # 📐 Pixel space between row slots vertically
func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Kept awake during game state pauses!
	
	_apply_custom_panel_texture()
	_build_72_inventory_slots()
	_populate_test_database_cards() # Seed example starter cards instantly to test!

# =========================================================================
# ⌨️ THE KEYBOARD "I" TOGGLE SYSTEM
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		get_viewport().set_input_as_handled()
		visible = !visible
		
		if visible:
			get_tree().paused = true
			render_overlapping_reservoir_tray()
			_update_slot_graphics_displays()
		else:
			get_tree().paused = false

# =========================================================================
# 🎨 PROCEDURAL PANEL TEXTURE PAINTER
# =========================================================================
func _apply_custom_panel_texture() -> void:
	if is_instance_valid(inventory_container) and is_instance_valid(inventory_panel_texture):
		var custom_style = StyleBoxTexture.new()
		custom_style.texture = inventory_panel_texture
		inventory_container.add_theme_stylebox_override("panel", custom_style)
func _build_72_inventory_slots() -> void:
	for child in left_melee_grid.get_children(): child.queue_free()
	for child in right_range_grid.get_children(): child.queue_free()
	
	left_melee_grid.size_flags_horizontal = Control.SIZE_FILL
	left_melee_grid.size_flags_vertical = Control.SIZE_FILL
	right_range_grid.size_flags_horizontal = Control.SIZE_FILL
	right_range_grid.size_flags_vertical = Control.SIZE_FILL
	
	left_melee_grid.add_theme_constant_override("h_separation", GRID_COLUMN_GAP)
	left_melee_grid.add_theme_constant_override("v_separation", GRID_ROW_GAP)
	right_range_grid.add_theme_constant_override("h_separation", GRID_COLUMN_GAP)
	right_range_grid.add_theme_constant_override("v_separation", GRID_ROW_GAP)

	# Create 36 Left Melee Slots
	for i in range(36):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(16, 16)
		slot.size = Vector2(16, 16)
		slot.name = "MeleeSlot_" + str(i)
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		
		var slot_sprite = AnimatedSprite2D.new()
		slot_sprite.name = "SlotIcon"
		slot_sprite.centered = false
		slot.add_child(slot_sprite)
		
		left_melee_grid.add_child(slot)
		left_melee_slots.append(slot)
		
		slot.pressed.connect(func(): _on_slot_clicked("melee", i))
		
	# Create 36 Right Range Slots
	for i in range(36):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(16, 16)
		slot.size = Vector2(16, 16)
		slot.name = "RangeSlot_" + str(i)
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		
		var slot_sprite = AnimatedSprite2D.new()
		slot_sprite.name = "SlotIcon"
		slot_sprite.centered = false
		slot.add_child(slot_sprite)
		
		right_range_grid.add_child(slot)
		right_range_slots.append(slot)
		
		slot.pressed.connect(func(): _on_slot_clicked("range", i))
func render_overlapping_reservoir_tray() -> void:
	for child in bottom_deck_reservoir.get_children(): child.queue_free()
	
	var unassigned_indices: Array[int] = []
	for i in range(collected_cards_data.size()):
		if collected_cards_data[i].current_slot == -1:
			unassigned_indices.append(i)
			
	var count = unassigned_indices.size()
	if count == 0: return
	
	var overlap_gap: float = 6.0 
	var center_x = bottom_deck_reservoir.size.x / 2.0
	var total_width = (count - 1) * overlap_gap
	var starting_x = center_x - (total_width / 2.0)
	
	for i in range(count):
		var data_idx = unassigned_indices[i]
		var card_data = collected_cards_data[data_idx]
		
		var card_btn = TextureButton.new()
		card_btn.custom_minimum_size = Vector2(16, 16)
		card_btn.size = Vector2(16, 16)
		card_btn.position = Vector2(starting_x + (i * overlap_gap), 0.0)
		card_btn.z_index = i
		
		var sprite = AnimatedSprite2D.new()
		sprite.name = "CardIcon"
		sprite.centered = false
		if is_instance_valid(master_sprite_frames):
			sprite.sprite_frames = master_sprite_frames
			sprite.animation = "upgrades"
			sprite.frame = card_data.frame_index
			sprite.stop()
		card_btn.add_child(sprite)
		
		if card_data.subtype == "attack":
			card_btn.self_modulate = Color(1.0, 0.6, 0.3) # Hot orange for primary weapons
		else:
			card_btn.self_modulate = Color(0.4, 0.7, 1.0) # Neon blue for attribute chips
			
		if data_idx == active_selected_card_index:
			card_btn.position.y -= 4.0 # Selection pop lift!
			card_btn.self_modulate = card_btn.self_modulate.lightened(0.3)
			
		bottom_deck_reservoir.add_child(card_btn)
		card_btn.pressed.connect(func(): _on_hand_card_clicked(data_idx))
func _on_hand_card_clicked(global_array_index: int) -> void:
	if active_selected_card_index == global_array_index:
		active_selected_card_index = -1 
	else:
		active_selected_card_index = global_array_index
	render_overlapping_reservoir_tray()

func _on_slot_clicked(side: String, slot_idx: int) -> void:
	if active_selected_card_index == -1:
		for card in collected_cards_data:
			if card.type == side and card.current_slot == slot_idx:
				card.current_slot = -1 
				_update_slot_graphics_displays()
				render_overlapping_reservoir_tray()
				return
		return
		
	var selected_card = collected_cards_data[active_selected_card_index]
	if selected_card.type != side: return # Locks type restrictions
		
	for card in collected_cards_data:
		if card.type == side and card.current_slot == slot_idx:
			card.current_slot = -1
			
	selected_card.current_slot = slot_idx
	active_selected_card_index = -1 
	
	_update_slot_graphics_displays()
	render_overlapping_reservoir_tray()
func _update_slot_graphics_displays() -> void:
	for slot in left_melee_slots:
		var icon: AnimatedSprite2D = slot.get_node("SlotIcon")
		icon.sprite_frames = null
	for slot in right_range_slots:
		var icon: AnimatedSprite2D = slot.get_node("SlotIcon")
		icon.sprite_frames = null
		
	for card in collected_cards_data:
		if card.current_slot != -1:
			var target_button: Button = null
			if card.type == "melee":
				target_button = left_melee_slots[card.current_slot]
			else:
				target_button = right_range_slots[card.current_slot]
				
			if is_instance_valid(target_button):
				var icon: AnimatedSprite2D = target_button.get_node("SlotIcon")
				if is_instance_valid(master_sprite_frames):
					icon.sprite_frames = master_sprite_frames
					icon.animation = "upgrades"
					icon.frame = card.frame_index
					icon.stop()

# =========================================================================
# 📦 DATABASE INGESTION SEED PIPELINES
# =========================================================================
func add_new_card_to_master_inventory(id: String, item_name: String, main_type: String, secondary_subtype: String, sheet_frame: int) -> void:
	var card = UpgradeCardData.new()
	card.id = id
	card.name = item_name
	card.type = main_type
	card.subtype = secondary_subtype
	card.frame_index = sheet_frame
	card.current_slot = -1 
	
	collected_cards_data.append(card)
	if visible:
		render_overlapping_reservoir_tray()

func _populate_test_database_cards() -> void:
	add_new_card_to_master_inventory("fire_slash", "Ember Cleave", "melee", "attack", 0)
	add_new_card_to_master_inventory("speed_chip", "Overclock Module", "melee", "modifier", 1)
	add_new_card_to_master_inventory("plasma_shot", "Blaster Matrix", "range", "attack", 2)
	add_new_card_to_master_inventory("range_extender", "Scope Mod", "range", "modifier", 3)
