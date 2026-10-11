extends Panel

@onready var item_visuals: Sprite2D = $CenterContainer/Panel/item_display

var slot_index: int = -1
var current_stored_item: Resource = null 
var parent_ui_manager: CanvasLayer = null

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func update(item: Resource) -> void:
	current_stored_item = item
	if not item or item.texture == null:
		item_visuals.visible = false
		item_visuals.texture = null
	else:
		item_visuals.texture = item.texture
		item_visuals.visible = true

func _on_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(parent_ui_manager): 
		return
		
	# 📤 MOUSE BUTTON CLICK DOWN: Pick up card
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_stored_item != null:
			accept_event()
			var item_to_lift = current_stored_item
			current_stored_item = null
			item_visuals.visible = false
			parent_ui_manager.lift_card_from_slot(slot_index, item_to_lift)
		
	# 📥 MOUSE BUTTON RELEASE: Check if we are dropping a dragged card into this slot
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		print("🖱️ SLOT RELEASE DETECTED on slot index: ", slot_index, " | Active Drag Source: ", parent_ui_manager.active_drag_source_index)
		if parent_ui_manager.active_drag_source_index != -1:
			accept_event()
			
			var source_idx = parent_ui_manager.active_drag_source_index
			var target_idx = slot_index
			
			print("📦 Triggering drop from ", source_idx, " to target slot ", target_idx)
			parent_ui_manager.active_drag_source_index = -1
			parent_ui_manager.drop_card_into_slot(source_idx, target_idx)
		else:
			print("❌ Drop rejected: active_drag_source_index was -1")
func _receive_dropped_card() -> void:
	pass
