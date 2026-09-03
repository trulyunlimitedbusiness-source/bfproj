extends CanvasLayer

@onready var inv: Inv = preload("res://upgrade system/inventory.tres")

# 🛰️ TRACKER DIRECTORIES
@onready var left_melee_grid: GridContainer = $NinePatchRect/GridContainer
@onready var storage_grid: GridContainer = $NinePatchRect/StorageGrid
@onready var left_hand_hud: VBoxContainer = get_node_or_null("../uiLayer/GameplayDeckHUD/LeftHandHUD")
@onready var right_hand_hud: VBoxContainer = get_node_or_null("../uiLayer/GameplayDeckHUD/RightHandHUD")

var slots: Array = []
var is_open = false
var active_drag_source_index: int = -1
var current_hovered_slot_index: int = -1

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Register this node instance with your global singleton bridge
	globals.inventory = self
	
	# Gather the visual panel child nodes from your grid containers
	var melee_children = left_melee_grid.get_children() if is_instance_valid(left_melee_grid) else []
	var storage_children = storage_grid.get_children() if is_instance_valid(storage_grid) else []
	
	slots.clear()
	slots.append_array(melee_children)     # Slots 0 to 71 (Active Left/Right Hands)
	slots.append_array(storage_children) # Slots 72+ (Your Bottom Deck Storage Rows)
	
	print("🛠️ INVENTORY UI: Visual layout mapped with: ", slots.size(), " total panel slots.")
	
	# =========================================================================
	# 🎒 THE STRUCTURAL DATA ADDRESS SHIELD
	# 💡 FIXED: If your saved inventory.tres file size is too small, your right hand
	# lanes (slots 36-71) will return null entries and do absolutely nothing!
	# This loop forcefully resizes your data array to perfectly match your slot count.
	# =========================================================================
	if is_instance_valid(inv):
		if inv.items.size() < slots.size():
			inv.items.resize(slots.size())
			print("📦 DATABASE FIXED: Resized inv.items array up to ", slots.size(), " addresses.")
			
		# Cleanse loop: Ensure it boots clean and fresh for your session
		for i in range(inv.items.size()):
			inv.items[i] = null
			
	# Map index identities cleanly onto every panel cell
	for i in range(slots.size()):
		var slot_node = slots[i]
		if is_instance_valid(slot_node):
			slot_node.slot_index = i
			slot_node.parent_ui_manager = self
			
	_initialize_floating_preview_layer()
	update_slots()
	close()

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
	# 🎒 INVENTORY WINDOW TOGGLE KEYS
	if Input.is_action_just_pressed("inv_open"):
		if is_open: close()
		else: open()
		return
		
	if globals.is_dead:
		visible = false
		return

	# Unconditional deck play cooldown clocks tracking countdown
	left_hand_cooldown -= delta
	right_hand_cooldown -= delta
	
	# =========================================================================
	# ⌨️ EXCLUSIVE DECK INPUT LISTENERS (GAMEPLAY ONLY)
	# =========================================================================
	if not is_open:
		# 🫱 LEFT HAND TRIGGERS: Capture Left Mouse Button Clicks or Named Actions
		var left_clicked: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if left_clicked:
			if not is_left_hand_streaming and not is_right_hand_streaming and left_hand_cooldown <= 0.0:
				is_left_hand_streaming = true
				left_hand_index_head = 0 # Force needle to start exactly at slot 0!
				left_hand_cooldown = 0.0
				print("🚀 DECK INITIALIZED: Left hand stream active. Tracking 36 steps uniformly.")
				
		# 🫲 RIGHT HAND TRIGGERS: Capture Right Mouse Button Clicks or Named Actions
		var right_clicked: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if right_clicked:
			if not is_left_hand_streaming and not is_right_hand_streaming and right_hand_cooldown <= 0.0:
				is_right_hand_streaming = true
				right_hand_index_head = 36 # Force needle to start exactly at slot 36!
				right_hand_cooldown = 0.0
				print("🚀 DECK INITIALIZED: Right hand stream active. Tracking 36 steps uniformly.")

	# =========================================================================
	# 🚀 DECK STREAM ENGINE CORE AUTOMATION
	# =========================================================================
	var can_weapon_execute: bool = true
	if is_instance_valid(globals.torch) and "can_shoot" in globals.torch:
		can_weapon_execute = globals.torch.can_shoot
	else:
		can_weapon_execute = true # Fallback safety line

	if can_weapon_execute:
		if is_left_hand_streaming and left_hand_cooldown <= 0.0:
			_process_sequential_deck_step(true)
		if is_right_hand_streaming and right_hand_cooldown <= 0.0:
			_process_sequential_deck_step(false)

	if not is_open: return
	
	# Dynamic Palette swinging physics loop running through un-parented overlay space
	if floating_preview_card and floating_preview_card.visible:
		var current_mouse_pos = get_viewport().get_mouse_position()
		floating_preview_card.global_position = current_mouse_pos - mouse_top_center_offset
		
		var mouse_velocity = current_mouse_pos.x - last_mouse_position.x
		last_mouse_position = current_mouse_pos
		
		var desired_tilt = clamp(mouse_velocity * 0.04, -0.45, 0.45)
		floating_preview_card.rotation = lerp(floating_preview_card.rotation, desired_tilt, 15.0 * delta)
		
		var hovered_idx = get_slot_index_under_mouse()
		
		# 🎴 DYNAMIC VISUAL CARDS MATRIX SHIFTER:
		for i in range(72, slots.size()):
			var slot_node = slots[i]
			if is_instance_valid(slot_node) and slot_node.visible:
				var card_visual_child = slot_node.get_node_or_null("CenterContainer")
				if is_instance_valid(card_visual_child):
					var target_x = 0.0
					if active_drag_source_index >= 72 and i > active_drag_source_index:
						target_x -= storage_remove_shift_amount
					if hovered_idx >= 72 and i >= hovered_idx:
						target_x += storage_shift_amount
					card_visual_child.position.x = lerp(card_visual_child.position.x, target_x, 16.0 * delta)
	else:
		for i in range(72, slots.size()):
			var slot_node = slots[i]
			if is_instance_valid(slot_node):
				var card_visual_child = slot_node.get_node_or_null("CenterContainer")
				if is_instance_valid(card_visual_child):
					card_visual_child.position.x = lerp(card_visual_child.position.x, 0.0, 16.0 * delta)

func get_slot_index_under_mouse() -> int:
	for i in range(slots.size()):
		var slot = slots[i]
		if is_instance_valid(slot) and slot.visible:
			var rect = Rect2(slot.global_position, slot.size)
			if rect.has_point(slot.get_global_mouse_position()):
				return i
	return -1
func _process_sequential_deck_step(is_left_hand: bool) -> void:
	if inv == null: return

	# 🔒 PRE-EXECUTION FUEL FIREWALL LOCKOUT
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
	
	# Safety termination gate: Wrap back to start if boundaries are breached
	if current_head < start_slot or current_head > end_slot:
		current_head = start_slot
		_terminate_active_hand_stream(is_left_hand, start_slot)
		return

	# Extract whatever card item is currently sitting beneath our timeline needle pointer
	var card_to_play: InvItem = null
	if current_head < inv.items.size():
		card_to_play = inv.items[current_head]

	# =========================================================================
	# ⏳ TRIPLE-TIER SPEED PACING PIPELINE
	# =========================================================================
	var current_step_cooldown: float = EMPTY_SLOT_SKIPPING_DELAY if "EMPTY_SLOT_SKIPPING_DELAY" in self else 0.01

	# =========================================================================
	# 🎭 UNIVERSAL DATA-DRIVEN CARD PLAYER
	# =========================================================================
	if card_to_play != null:
		# Extract the method name safely from your resource properties
		var target_method: String = ""
		if "attack_method_name" in card_to_play and card_to_play.attack_method_name != "":
			target_method = card_to_play.attack_method_name
		else:
			target_method = card_to_play.get("attack_method_name") if card_to_play.get("attack_method_name") != null else ""
		
		# Fallback checking path logic if method strings aren't typed out yet inside the .tres
		if target_method == "":
			if card_to_play.card_sprite_frame == 2: target_method = "shoot"
			elif card_to_play.card_sprite_frame == 3: target_method = "execute_melee_swipe_action"

		# Since there is a card here, default to your modifier pacing speed tier!
		current_step_cooldown = PADDING_SKIPPING_DELAY if "PADDING_SKIPPING_DELAY" in self else 0.03

		# Apply passive/modifier property value overrides onto singletons dynamically
		_apply_single_card_impact(card_to_play)

		# ⚔️ STEP 2: WEAPON ATTACK DISPATCHER CHANNEL
		if target_method != "":
			# Since this cell contains a true combat attack behavior, 
			# lock down the step timer delay to enforce your full deck fire rate cooldown buffer rhythm!
			current_step_cooldown = BASE_DECK_SPEED_DELAY
			
			if is_instance_valid(globals.torch):
				if globals.torch.has_method("force_interrupt_current_attack_state"):
					globals.torch.force_interrupt_current_attack_state()
				if globals.torch.has_method(target_method):
					globals.torch.call(target_method)
	else:
		# Forcefully ensures completely empty cells use your ultra-rapid delay!
		current_step_cooldown = EMPTY_SLOT_SKIPPING_DELAY if "EMPTY_SLOT_SKIPPING_DELAY" in self else 0.01

	# Advance our timeline pointer needle forward by exactly one slot cell per beat
	current_head += 1

	# =========================================================================
	# 🏁 END-OF-HAND DECK RESETS
	# 💡 FIXED: Before shutting down the stream, we commit the active recovery 
	# cooldown timer value ('current_step_cooldown') back into the hand lanes!
	# This ensures your fire rates are perfectly locked even if attacks sit at the very end.
	# =========================================================================
	if current_head > end_slot:
		current_head = start_slot # Reset loop needle position back to front cell
		
		if is_left_hand:
			is_left_hand_streaming = false
			left_hand_index_head = current_head
			left_hand_cooldown = current_step_cooldown # Enforces the weapon fire rate gate before next click!
		else:
			is_right_hand_streaming = false
			right_hand_index_head = current_head
			right_hand_cooldown = current_step_cooldown # Enforces the weapon fire rate gate before next click!
			
		# Hard flush: Wipes away modifier residues and restores clean passive defaults!
		update_slots()
		return

	# Save updated tracking needle cursor positions back into state variables
	if is_left_hand:
		left_hand_index_head = current_head
		left_hand_cooldown = current_step_cooldown
	else:
		right_hand_index_head = current_head
		right_hand_cooldown = current_step_cooldown
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
func _apply_single_card_impact(equipped_card: InvItem) -> void:
	if not is_instance_valid(equipped_card): return
	
	var f_id = equipped_card.card_sprite_frame
	
	if f_id == 0:
		if is_instance_valid(globals.player):
			globals.player.SPEED *= 1.5
			globals.player.STEP_DELAY /= 1.5
			
	elif f_id == 1:
		if is_instance_valid(globals.torch):
			globals.torch.SWIPE_DAMAGE *= 1.5
			globals.torch.damage *= 1.7
			
	elif f_id == 4:
		if is_instance_valid(globals.torch):
			globals.torch.speed *= 1.5
			globals.torch.max_range *= 1.5
			
	elif f_id == 5:
		if is_instance_valid(globals.torch):
			globals.torch.accuracy_spread_degrees /= 1.5
			
	elif f_id == 6:
		if is_instance_valid(globals.torch):
			globals.torch.overheat_cost /= 1.5
			
	elif f_id == 7:
		if is_instance_valid(globals.torch):
			globals.torch.fuel_cost /= 1.6
			
	elif f_id == 8:
		if is_instance_valid(globals.torch):
			globals.torch.shoot_count += 1
			
	elif f_id == 9:
		if is_instance_valid(globals.player):
			globals.player.RECOIL_FORCE *= 1.8
			
	elif f_id == 10:
		if is_instance_valid(globals.player):
			globals.player.slipperiness += 0.45
			globals.player.slipperiness *= 1.7
			globals.player.slide_speed *= 1.5
			globals.player.FRICTION /= 1.5
			
	elif f_id == 11:
		if is_instance_valid(globals.torch):
			# Set up our absolute resting ceiling cap and our dramatic overshoot peak
			var resting_modifier_scale = Vector2(1.3, 1.3)
			var explosive_overshoot_peak = Vector2(1.5, 1.5)
			
			# Keep your backend projectile mathematical values locked to their ceiling caps
			globals.torch.projectile_size = Vector2(1.3, 1.3)
			
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
			globals.torch.damage *= 1.15
			globals.torch.SWIPE_DAMAGE *= 1.15
func update_slots() -> void:
	active_drag_source_index = -1
	current_dragged_item_resource = null
	if floating_preview_card: 
		floating_preview_card.visible = false
		
	if is_instance_valid(storage_grid):
		storage_grid.add_theme_constant_override("h_separation", storage_overlap_gap)
		
	# A. Gathers all valid storage items, compressing them leftward cleanly
	var active_storage_resources: Array[Resource] = []
	for i in range(72, inv.items.size()):
		if inv.items[i] != null:
			active_storage_resources.append(inv.items[i])
			
	for i in range(72, inv.items.size()):
		var storage_idx = i - 72
		if storage_idx < active_storage_resources.size():
			inv.items[i] = active_storage_resources[storage_idx]
		else:
			inv.items[i] = null
			
	# B. Redraw cell graphics over your manual editor slot panels
	for i in range(min(inv.items.size(), slots.size())):
		if is_instance_valid(slots[i]):
			slots[i].visible = true
			slots[i].update(inv.items[i])
			if i >= 72:
				var card_visual_child = slots[i].get_node_or_null("CenterContainer")
				if is_instance_valid(card_visual_child):
					card_visual_child.position.x = 0.0
					
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
		globals.player.SPEED = 120.0
		globals.player.RECOIL_FORCE = 80.0
		globals.player.STEP_DELAY = 0.35
		globals.player.slipperiness = 0.0
		globals.player.slide_speed = 0.0
		globals.player.FRICTION = 1500.0
		
		# Keep your backend projectile mathematical values locked to baseline caps instantly
		globals.torch.projectile_size = Vector2(1.0, 1.0)
		
		# Set up our absolute resting baseline size and our dramatic undershoot snap peak
		var resting_baseline_scale = Vector2(1.0, 1.0)
		var elastic_undershoot_peak = Vector2(0.7, 0.7)
		
		# =========================================================================
		# 🪀 THE SCALE VALIDATION FIREWALL GATE
		# 💡 FIXED: Only triggers the springy collapse animation if the torch was 
		# actually modified and scaled up past its baseline 1.0 limit!
		# If it's already at normal scale, it skips the wobble to prevent ghost snaps.
		# =========================================================================
		if globals.torch.scale.x > 1.01 or globals.torch.scale.y > 1.01:
			var reset_tween = globals.torch.create_tween()
			
			# STAGE 1: Rapid structural contraction snap (Crisp and swift)
			reset_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			reset_tween.tween_property(globals.torch, "scale", elastic_undershoot_peak, 0.10)
			
			# STAGE 2: The Snap-Up Wobble (Chained automatically to ripple back to normal)
			reset_tween.chain().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			reset_tween.tween_property(globals.torch, "scale", resting_baseline_scale, 0.50)
			
			# If you have an inner sprite node child, mirror the exact same elastic bounce over it
			var torch_sprite = globals.torch.get_node_or_null("AnimatedSprite2D")
			if is_instance_valid(torch_sprite):
				var sprite_tween = torch_sprite.create_tween()
				sprite_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				sprite_tween.tween_property(torch_sprite, "scale", elastic_undershoot_peak, 0.10)
				sprite_tween.chain().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				sprite_tween.tween_property(torch_sprite, "scale", Vector2.ONE, 0.50)
		else:
			# 🔒 SOLID QUIET SNAP FALLBACK: If the size modifier wasn't active, 
			# quietly lock the values back to normal with zero visual disruptions!
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

	if is_instance_valid(globals.left_hand_hud_container):
		var hud_slots = globals.left_hand_hud_container.get_children()
		for i in range(12):
			if i < hud_slots.size():
				var hud_slot_cell = hud_slots[i]
				var backend_item = inv.items[i]
				
				if is_instance_valid(hud_slot_cell):
					# 🛡️ Fallback Gate: Use the custom method if it exists, otherwise assign the asset directly
					if hud_slot_cell.has_method("update"):
						hud_slot_cell.update(backend_item)
					elif "texture" in hud_slot_cell:
						hud_slot_cell.texture = backend_item.texture if backend_item != null else null
					elif hud_slot_cell.has_node("TextureRect"):
						var inner_tex = hud_slot_cell.get_node("TextureRect") as TextureRect
						if is_instance_valid(inner_tex):
							inner_tex.texture = backend_item.texture if backend_item != null else null

	# B. REFRESH RIGHT HAND HUD (Slots 36 to 47)
	if is_instance_valid(globals.right_hand_hud_container):
		var hud_slots = globals.right_hand_hud_container.get_children()
		for i in range(12):
			if i < hud_slots.size():
				var hud_slot_cell = hud_slots[i]
				var backend_item = inv.items[36 + i]
				
				if is_instance_valid(hud_slot_cell):
					# 🛡️ Fallback Gate: Use the custom method if it exists, otherwise assign the asset directly
					if hud_slot_cell.has_method("update"):
						hud_slot_cell.update(backend_item)
					elif "texture" in hud_slot_cell:
						hud_slot_cell.texture = backend_item.texture if backend_item != null else null
					elif hud_slot_cell.has_node("TextureRect"):
						var inner_tex = hud_slot_cell.get_node("TextureRect") as TextureRect
						if is_instance_valid(inner_tex):
							inner_tex.texture = backend_item.texture if backend_item != null else null
func open():
	is_open = true
	visible = true
	if globals.player != null:
		globals.player.can_move = false
		globals.torch.can_shoot = false
	last_mouse_position = get_viewport().get_mouse_position()
	if is_instance_valid($NinePatchRect):
		# Centering the anchor point ensures it inflates symmetrically from the middle
		$NinePatchRect.pivot_offset = $NinePatchRect.size / 2.0
		
		# 💥 PUNCHY DEFAULTS: Start tiny and completely see-through
		$NinePatchRect.scale = Vector2(0.25, 0.25)
		$NinePatchRect.modulate.a = 0.0
		
		var open_tween = create_tween()
		open_tween.set_parallel(true)
		
		# An intense TRANS_BACK curve causes the menu to snap forward and pop outward noticeably!
		open_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		open_tween.tween_property($NinePatchRect, "scale", Vector2.ONE, 0.28)
		open_tween.tween_property($NinePatchRect, "modulate:a", 1.0, 0.16)

func close():
	if active_drag_source_index != -1: 
		update_slots()
	is_open = false
	if globals.player != null:
		globals.player.can_move = true
		globals.torch.can_shoot = true
	if is_instance_valid($NinePatchRect):
		$NinePatchRect.pivot_offset = $NinePatchRect.size / 2.0
		
		var close_tween = create_tween()
		close_tween.set_parallel(true)
		close_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		# 💥 SQUASH COLLAPSE: Flatten the X scale to zero while stretching Y to make it pop!
		close_tween.tween_property($NinePatchRect, "scale", Vector2(0.01, 1.25), 0.18)
		close_tween.tween_property($NinePatchRect, "modulate:a", 0.0, 0.14)
		
		# Ensure the visibility processor completely locks out rendering only when the path completes
		close_tween.chain().tween_callback(func():
			visible = false
		)
	else:
		visible = false
func drop_card_into_slot(from_idx: int, to_idx: int) -> void:
	if master_swap_tween and master_swap_tween.is_valid(): 
		return
		
	if from_idx == to_idx: 
		# 💡 FIXED: Stripped out the obsolete boolean parameter to match your clean signature!
		update_slots() 
		return
		
	if from_idx < inv.items.size() and to_idx < inv.items.size():
		var source_item = inv.items[from_idx]
		
		# 🎯 INTERSECTION TRACK: Slices your item directly into your bottom storage deck!
		if to_idx >= 72:
			inv.items[from_idx] = null
			inv.items.insert(to_idx, source_item)
			if inv.items.size() > slots.size(): 
				inv.items.resize(slots.size())
				
			if floating_preview_card and slots[to_idx]:
				var target_slot_node = slots[to_idx]
				var landing_offset = Vector2((SELECTED_SIZE - DROPPED_SIZE) / 2.0, 0.0)
				var adjusted_target_pos = target_slot_node.global_position - landing_offset
				var target_scale_fraction = DROPPED_SIZE / SELECTED_SIZE
				var target_scale_vector = Vector2(target_scale_fraction, target_scale_fraction)
				
				master_swap_tween = create_tween()
				master_swap_tween.set_parallel(true)
				master_swap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				master_swap_tween.tween_property(floating_preview_card, "global_position", adjusted_target_pos, 0.18)
				master_swap_tween.tween_property(floating_preview_card, "scale", target_scale_vector, 0.18)
				master_swap_tween.tween_property(floating_preview_card, "rotation", 0.0, 0.14)
				
				master_swap_tween.chain().tween_callback(func(): 
					# 💡 FIXED: Clean baseline refresh pass on drop completion
					update_slots() 
				)
			else:
				update_slots()
			return

		# Standard layout swapping logic for your 72 main grid slots up top
		var target_item = inv.items[to_idx]
		var target_scale_fraction = DROPPED_SIZE / SELECTED_SIZE
		var target_scale_vector = Vector2(target_scale_fraction, target_scale_fraction)
		
		var origin_slot_node = slots[from_idx]
		var target_slot_node = slots[to_idx]
		
		if not is_instance_valid(origin_slot_node) or not is_instance_valid(target_slot_node):
			inv.items[to_idx] = source_item
			inv.items[from_idx] = target_item
			update_slots()
			return
			
		if target_item != null:
			if "item_visuals" in origin_slot_node and is_instance_valid(origin_slot_node.item_visuals):
				origin_slot_node.item_visuals.visible = false
			if "item_visuals" in target_slot_node and is_instance_valid(target_slot_node.item_visuals):
				target_slot_node.item_visuals.visible = false
				
			var secondary_swap_card = TextureRect.new()
			secondary_swap_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			secondary_swap_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			secondary_swap_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			secondary_swap_card.stretch_mode = TextureRect.STRETCH_SCALE
			secondary_swap_card.texture = target_item.texture
			secondary_swap_card.custom_minimum_size = Vector2(SELECTED_SIZE, SELECTED_SIZE)
			secondary_swap_card.size = Vector2(SELECTED_SIZE, SELECTED_SIZE)
			secondary_swap_card.pivot_offset = mouse_top_center_offset
			
			var landing_offset = Vector2((SELECTED_SIZE - DROPPED_SIZE) / 2.0, 0.0)
			var adjusted_target_pos = target_slot_node.global_position - landing_offset
			var adjusted_origin_pos = origin_slot_node.global_position - landing_offset
			
			secondary_swap_card.global_position = target_slot_node.global_position - landing_offset
			secondary_swap_card.scale = target_scale_vector
			add_child(secondary_swap_card)
			
			inv.items[to_idx] = source_item
			inv.items[from_idx] = target_item
			
			master_swap_tween = create_tween()
			master_swap_tween.set_parallel(true)
			master_swap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			master_swap_tween.tween_property(floating_preview_card, "global_position", adjusted_target_pos, 0.18)
			master_swap_tween.tween_property(floating_preview_card, "scale", target_scale_vector, 0.18)
			master_swap_tween.tween_property(floating_preview_card, "rotation", 0.0, 0.14)
			master_swap_tween.tween_property(secondary_swap_card, "global_position", adjusted_origin_pos, 0.18)
			
			master_swap_tween.chain().tween_callback(func(): 
				if is_instance_valid(secondary_swap_card): 
					secondary_swap_card.queue_free()
				# 💡 FIXED: Clean baseline refresh pass on swap completion
				update_slots() 
			)
		else:
			inv.items[to_idx] = source_item
			inv.items[from_idx] = target_item
			
			if floating_preview_card:
				var landing_offset = Vector2((SELECTED_SIZE - DROPPED_SIZE) / 2.0, 0.0)
				var adjusted_target_pos = target_slot_node.global_position - landing_offset
				
				master_swap_tween = create_tween()
				master_swap_tween.set_parallel(true)
				master_swap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				master_swap_tween.tween_property(floating_preview_card, "global_position", adjusted_target_pos, 0.18)
				master_swap_tween.tween_property(floating_preview_card, "scale", target_scale_vector, 0.18)
				master_swap_tween.tween_property(floating_preview_card, "rotation", 0.0, 0.14)
				
				master_swap_tween.chain().tween_callback(func(): 
					# 💡 FIXED: Clean baseline refresh pass on drop completion
					update_slots() 
				)
			else:
				update_slots()
func lift_card_from_slot(source_idx: int, item: Resource) -> void:
	active_drag_source_index = source_idx
	current_dragged_item_resource = item
	if floating_preview_card and item:
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
