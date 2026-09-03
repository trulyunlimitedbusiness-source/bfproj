extends Button
@export var hover_scale: Vector2 = Vector2(1.3, 1.3) # Grow by 15% on hover
@export var normal_scale: Vector2 = Vector2(1.0, 1.0)
@export var tween_duration: float = 0.12 # Fast, snappy arcade response

var scale_tween: Tween = null

func _ready() -> void:
	# 2. FORCE THE CENTER PIVOT POINT ENGINE
	# We wait 1 physics frame for the VBoxContainer to calculate the button's real size layout,
	# then we snap the pivot point to the absolute geometric core of the text box.
	await get_tree().physics_frame
	pivot_offset = size / 2.0
	
	# 3. DIRECTLY CONNECT THE MOUSE HOVER SIGNALS IN CODE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	animate_button_scale(hover_scale)
	$"../../click1".pitch_scale = randf_range(0.88, 1.12)
	$"../../click1".play()
func _on_mouse_exited() -> void:
	animate_button_scale(normal_scale)

func animate_button_scale(target_scale: Vector2) -> void:
	# 4. RESET THE PIPELINE: Kill any active running animations to prevent stuttering 
	# if the player rapidly glides the cursor across your button text
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
		
	scale_tween = create_tween()
	
	# Configure a crisp, springy mechanical curve
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.set_ease(Tween.EASE_OUT)
	
	# Smoothly stretch the button dimensions over a rapid 0.12 seconds
	scale_tween.tween_property(self, "scale", target_scale, tween_duration)

func _on_pressed() -> void:
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://main.tscn")
