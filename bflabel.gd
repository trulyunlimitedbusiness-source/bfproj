extends Label

# 1. TUNING CONFIGURATIONS
@export var peak_scale: Vector2 = Vector2(1.12, 1.12) # Scale up by 12% at the top of the pop
@export var base_scale: Vector2 = Vector2(1.0, 1.0)
@export var pop_duration: float = 0.6 # How many seconds it takes to expand (Lower = faster pop!)

# 📐 NEW: RETRO ARCADE TILT VALUES
@export var max_tilt_degrees: float = 4.0 # How many degrees the title sways left and right

var title_loop_tween: Tween = null

func _ready() -> void:
	# Start the infinite arcade pulse and rock engine
	start_title_pop_loop()

func _process(_delta: float) -> void:
	# Continuously lock the pivot offset to the dead-center pixels of the text string
	pivot_offset = size / 2.0

func start_title_pop_loop() -> void:
	# Kill any active loops to prevent memory leaks if initialized multiple times
	if title_loop_tween and title_loop_tween.is_valid():
		title_loop_tween.kill()
		
	# =========================================================================
	# 🚀 ENGINE 1: THE INFINITE SCALE PULSE TRACK
	# Explicitly handles expanding and deflating the text size smoothly.
	# =========================================================================
	var scale_tween = create_tween()
	scale_tween.set_loops()
	scale_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Pop forward to 112% size, then smoothly deflate back down to normal
	scale_tween.tween_property(self, "scale", peak_scale, pop_duration)
	scale_tween.tween_property(self, "scale", base_scale, pop_duration)
	
	# =========================================================================
	# 🔄 ENGINE 2: THE INFINITE SEPARATE ROTATION SWAY TRACK
	# Explicitly handles rocking the text left and right on its center pivot.
	# 💡 FIXED: By separating this from the scale track, they can never clash!
	# =========================================================================
	title_loop_tween = create_tween()
	title_loop_tween.set_loops()
	title_loop_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var target_radian_tilt = deg_to_rad(max_tilt_degrees)
	
	# Rock gracefully to the right, then swing completely past center over to the left!
	# ⏱️ We double the duration on the sway return line so the travel velocity 
	# across the full wide arc feels heavy, balanced, and perfectly fluid.
	title_loop_tween.tween_property(self, "rotation", target_radian_tilt, pop_duration)
	title_loop_tween.tween_property(self, "rotation", -target_radian_tilt, pop_duration * 2.0)
	title_loop_tween.tween_property(self, "rotation", 0.0, pop_duration)
