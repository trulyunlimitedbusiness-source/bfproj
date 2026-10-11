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
	var ui_manager_node = globals.inventory
	
	if is_instance_valid(ui_manager_node) and "inv" in ui_manager_node and ui_manager_node.inv != null:
		# 🔒 STRICTLY ENFORCE MAX 160 SLOTS TO PREVENT 412-SLOT EXPLOSION
		if ui_manager_node.inv.items.size() != 160:
			ui_manager_node.inv.items.resize(160)
			
		# =========================================================================
		# 🎴 THE DIRECT RESOURCE FACTORY
		# =========================================================================
		var current_frame = $AnimatedSprite2D.frame
		var picked_up_card = InvItem.new()
		picked_up_card.card_sprite_frame = current_frame
		
		# Pull texture from the AnimatedSprite2D frame
		if $AnimatedSprite2D.sprite_frames:
			picked_up_card.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, current_frame)
			
		# Explicit string & property mapping for active vs passive cards
		match current_frame:
			0: picked_up_card.name = "Sprint"
			1: picked_up_card.name = "Damage"
			2: picked_up_card.name = "Ranged"
			3: picked_up_card.name = "Melee"
			4: picked_up_card.name = "Velocity"
			5: picked_up_card.name = "Accuracy"
			6: picked_up_card.name = "Cooling"
			7: picked_up_card.name = "Efficiency"
			8: picked_up_card.name = "Multishot"
			9: picked_up_card.name = "Knockback"
			10: picked_up_card.name = "Slide"
			11: picked_up_card.name = "Attack Size"
			12: picked_up_card.name = "Deck Speed"
			13: picked_up_card.name = "Enemy Knockback"
			18:
				picked_up_card.name = "Everythingallthetime"
				picked_up_card.is_passive = true
				picked_up_card.description = "Everything all of the time:\nEvery modifier is upgraded by 50%"
			_:
				if has_meta("is_passive"):
					picked_up_card.is_passive = get_meta("is_passive")

		print("🔍 [COLLECT DEBUG] Created Resource: ", picked_up_card.name, " | Frame: ", current_frame, " | Is Passive: ", picked_up_card.is_passive)
		print("🔍 [COLLECT DEBUG] Current Global Inv Size: ", ui_manager_node.inv.items.size())

		# =========================================================================
		# 🎒 STORAGE DECK INGESTION ARRAY PASS
		# 💡 Passive Cards -> Slots 140 to 159 (Passive Storage)
		# 💡 Active Cards  -> Slots 0 to 71 (Active Grid) [FIXED]
		# =========================================================================
		var start_slot: int = 140 if picked_up_card.is_passive else 72
		var end_slot: int = 160 if picked_up_card.is_passive else 92
		
		print("🔍 [COLLECT DEBUG] Scanning slot range: ", start_slot, " to ", end_slot - 1)

		var insert_success: bool = false
		for i in range(start_slot, end_slot):
			if i < ui_manager_node.inv.items.size() and ui_manager_node.inv.items[i] == null:
				ui_manager_node.inv.items[i] = picked_up_card
				insert_success = true
				print("✅ [COLLECT DEBUG] Directly inserted item into index ", i, " -> Item Name: ", ui_manager_node.inv.items[i].name)
				break

		if not insert_success:
			print("❌ [COLLECT DEBUG] Insertion failed! Range was full or invalid.")

		# =========================================================================
		# 🔄 VISUAL REFRESH
		# =========================================================================
		if insert_success:
			if ui_manager_node.has_method("update_slots"):
				ui_manager_node.update_slots()
				print("🔄 [COLLECT DEBUG] Called update_slots().")

	# Execute elastic shrink tweens on collection
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
