extends Area2D

# 🎨 Make sure this name matches the AnimatedSprite2D child node in your scene tree!
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 

var move_direction: Vector2 = Vector2.ZERO
var starting_position: Vector2 = Vector2.ZERO
var iao: bool = false # Tracks if we are actively "Animating Out"
func _ready() -> void:
	add_to_group("bullets")
	
	# 💡 FIXED: Read the clean independent directional vector we injected from the torch script!
	if move_direction == Vector2.ZERO:
		move_direction = Vector2.RIGHT.rotated(global_rotation)
		
	starting_position = global_position
	
	# Wire up the environment obstacle collision connection automatically at birth
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# If we are actively exploding or scaling away, freeze movement instantly!
	if iao: return
	
	# Flight path velocity translation loop axis line tracking
	global_position += move_direction * globals.torch.speed * delta
	
	# Range Gate: If the bullet travels past its maximum pixel boundary, burn out!
	if global_position.distance_to(starting_position) >= globals.torch.max_range:
		animating_out()

func animating_out() -> void:
	if iao: return # Anti-trigger shield: prevents overlapping duplicate calls
	iao = true
	sprite.play("default")
		
	# =========================================================================
	# ⏱️ STEP 2: THE MICRO-FRAME BREAK (THE INDEPENDENCE FIX)
	# We force the script to wait for a tiny fraction of a second (0.04s).
	# This lets the sprite engine advance and render the initial splash frames 
	# onto the monitor before the scaling math can freeze its clock registers!
	# =========================================================================
	await get_tree().create_timer(0.04).timeout
	
	# If the projectile node was accidentally destroyed during the micro-wait, abort!
	if not is_instance_valid(sprite): return
	
	# =========================================================================
	# 🛠️ STEP 3: THE DECOUPLED SCALE-BOUNCE CHAIN
	# =========================================================================
	var burst_tween = create_tween()
	
	# A. TARGETED CHILD INFLATION: Balloon the sprite to double size instantly!
	burst_tween.set_ease(Tween.EASE_OUT)
	burst_tween.set_trans(Tween.TRANS_BACK)
	burst_tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.20)
	
	# B. THE DEFLATION CHAIN: Smoothly shrink down to absolute zero space.
	# Because the animation is already running freely, it will play flawlessly as it melts away!
	burst_tween.chain().set_ease(Tween.EASE_OUT)
	burst_tween.chain().set_trans(Tween.TRANS_CUBIC)
	burst_tween.chain().tween_property(sprite, "scale", Vector2.ZERO, 0.7)
	
	# C. SAFE SYSTEM MEMORY PURGE
	burst_tween.chain().tween_callback(queue_free)
func _on_body_entered(body: Node2D) -> void:
	if iao: return
	var camera = get_tree().get_first_node_in_group("camera")
	# 🤖 ENEMY HIT DETECTION
	if body.has_method("take_damage"):
		body.take_damage(globals.torch.damage)
		animating_out() # Instantly dissolve on contact
		return
		
	# 🧱 WALL / TILEMAP CONTACT DETECTION
	# If the projectile hits your solid environmental grid walls node, smash and dissolve!
	if body is TileMapLayer or TileMap:
		animating_out()
		camera.add_shake(2.0)
		$impact.volume_db = randf_range(5.7, 6.3)
		$impact.pitch_scale = randf_range(0.75, 1.22)
		$impact.play()
