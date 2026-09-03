extends Area2D

class_name UpgradeCardNode
var in_range: bool = false
enum cards {speed, armor}
enum card_type {player, weapon, time}
var current_card = cards.speed
var current_type = card_type.player
@export var frame = 0
func _ready() -> void:
	$AnimatedSprite2D.frame = frame
	$Label.visible = false
	add_to_group("collectables")
	scale = Vector2.ZERO
	var spawn_tween = create_tween()
	spawn_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.6)
func _process(_delta: float) -> void:
	if in_range and globals.player:
		if Input.is_action_just_pressed("interact"):
			collect_item()
func collect_item() -> void:
	in_range = false
	
	# 🛰️ CENTRAL COMMUNICATION BRIDGE LOOKUP
	# We look up your canvas node instantly via your global singleton!
	var ui_manager_node = globals.inventory
	
	if is_instance_valid(ui_manager_node) and "inv" in ui_manager_node and ui_manager_node.inv != null:
		# =========================================================================
		# 🎴 THE DIRECT RESOURCE FACTORY
		# 💡 FIXED: Dynamically creates a clean database item resource on the fly, 
		# stamping your ground card's animated sprite texture and active frame ID!
		# =========================================================================
		var picked_up_card = InvItem.new()
		picked_up_card.card_sprite_frame = $AnimatedSprite2D.frame
		
		# Pull the frame texture out of your sheet to draw inside your UI grid slot graphics
		if $AnimatedSprite2D.sprite_frames:
			picked_up_card.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, $AnimatedSprite2D.frame)
			
		# Explicit string mapping helps you monitor data arrays inside the console debug tracks
		if $AnimatedSprite2D.frame == 0:
			picked_up_card.name = "Sprint"
		elif $AnimatedSprite2D.frame == 1:
			picked_up_card.name = "Damage"
		elif $AnimatedSprite2D.frame == 2:
			picked_up_card.name = "Ranged"
		elif $AnimatedSprite2D.frame == 3:
			picked_up_card.name = "Melee"
		elif $AnimatedSprite2D.frame == 4:
			picked_up_card.name = "Velocity"
		elif $AnimatedSprite2D.frame == 5:
			picked_up_card.name = "Accuracy"
		elif $AnimatedSprite2D.frame == 6:
			picked_up_card.name = "Cooling"
		elif $AnimatedSprite2D.frame == 7:
			picked_up_card.name = "Efficiency"
		elif $AnimatedSprite2D.frame == 8:
			picked_up_card.name = "Multishot"
		elif $AnimatedSprite2D.frame == 9:
			picked_up_card.name = "Knockback"
		elif $AnimatedSprite2D.frame == 10:
			picked_up_card.name = "Slide"
		elif $AnimatedSprite2D.frame == 11:
			picked_up_card.name = "Attack Size"
			
		# =========================================================================
		# 🎒 STORAGE DECK INGESTION ARRAY PASS
		# 💡 FIXED: Explicitly starts scanning starting from slot index 72!
		# Pushes your collected ground item resource straight into your fanned deck tray.
		# =========================================================================
		var insert_success: bool = false
		for i in range(72, ui_manager_node.inv.items.size()):
			if ui_manager_node.inv.items[i] == null:
				ui_manager_node.inv.items[i] = picked_up_card
				insert_success = true
				break # Stop loop processing once a home is locked in!

		# Force a visual panel layout redraw if the card was successfully tucked away
		if insert_success and ui_manager_node.has_method("update_slots"):
			ui_manager_node.update_slots()

	# Execute your original elastic shrink tweens beautifully on collection ticks
	var shrink_tween = create_tween()
	shrink_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink_tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	shrink_tween.parallel().tween_property(self, "global_position:y", global_position.y - 15.0, 0.12)
	shrink_tween.finished.connect(func(): queue_free())
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		$Label.visible = true
		in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		$Label.visible = false
		in_range = false
