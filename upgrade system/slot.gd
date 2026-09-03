extends Panel

@onready var item_visuals: Sprite2D = $CenterContainer/Panel/item_display

var slot_index: int = -1
var current_stored_item: Resource = null 
var parent_ui_manager: CanvasLayer = null

# Keep track of whether the mouse cursor is currently hovering over this specific slot cell
var is_mouse_hovering: bool = false

func _ready() -> void:
	# Connect your input and mouse listeners safely to protect node lines from breaking
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): is_mouse_hovering = true)
	mouse_exited.connect(func(): is_mouse_hovering = false)

func update(item: Resource) -> void:
	current_stored_item = item
	if not item:
		item_visuals.visible = false
	else:
		item_visuals.visible = true
		item_visuals.texture = item.texture

# =========================================================================
# 🖱️ SIGNAL-DRIVEN CLICK MOUSE INPUT LISTENER
# 💡 FIXED: Replaced native drag methods entirely! Pressing the mouse button down
# instantly picks up the card, and releasing the mouse checks if you are over
# a valid slot cell, completely bypassing the red circle "no" sign bug!
# =========================================================================
func _on_gui_input(event: InputEvent) -> void:
	if current_stored_item == null or not is_instance_valid(parent_ui_manager): 
		return
		
	# 📤 MOUSE BUTTON CLICK DOWN: Instantly pick up the card asset!
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event() # Mute input leakage
		parent_ui_manager.lift_card_from_slot(slot_index, current_stored_item)
		item_visuals.visible = false # Hide immediately on click frame!
		
	# 📥 MOUSE BUTTON RELEASE: Attempt to drop the item!
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if parent_ui_manager.active_drag_source_index == slot_index:
			accept_event()
			
			# Scan through all 72 slots to check which one the mouse is hovering over right now
			var dropped_on_slot: bool = false
			for slot in parent_ui_manager.slots:
				if is_instance_valid(slot) and slot.is_mouse_hovering:
					dropped_on_slot = true
					slot._receive_dropped_card() # Deliver the drop cargo packet!
					break
					
			# 🛡️ FAIL-SAFE SNAP BACK: If released in empty space, reset layout smoothly!
			if not dropped_on_slot:
				parent_ui_manager.update_slots()

# Internal execution link called by the slot you successfully released the mouse over
# =========================================================================
func _receive_dropped_card() -> void:
	if is_instance_valid(parent_ui_manager):
		var from_index = parent_ui_manager.active_drag_source_index
		parent_ui_manager.drop_card_into_slot(from_index, slot_index)
