extends Node2D

@export_group("Spawner Configurations")
@export var SPAWN_RADIUS_X: float = 300.0 
@export var SPAWN_RADIUS_Y: float = 200.0 
@export var spawn_cooldown: float = 1.5 
@export var startup_time: float = 3.0 
@export var spawn_amount: int = 10 

@onready var spawn_timer: Timer = $SpawnTimer

# 📁 Ensure this path points exactly to your liquid enemy scene file!
const ENEMY_SCENE = preload("res://enemy/liquid.tscn")

func _ready() -> void:
	if spawn_timer:
		# Set the startup delay time first
		spawn_timer.wait_time = startup_time if startup_time > 0.0 else spawn_cooldown
		spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	# If this is the very first tick out of the startup delay, switch to your standard cooldown pace
	if spawn_timer.wait_time == startup_time:
		spawn_timer.wait_time = spawn_cooldown
		spawn_timer.start() # Restart timer with the fresh operational wait time
		
	if spawn_amount > 0:
		# =========================================================================
		# 🧮 LOCAL RADIUS POSITION INFLATION
		# 💡 FIXED: We completely removed the player tracking system blocks!
		# The calculation now reads 'global_position' (where this spawner is placed).
		# =========================================================================
		var random_x: float = randf_range(-SPAWN_RADIUS_X, SPAWN_RADIUS_X)
		var random_y: float = randf_range(-SPAWN_RADIUS_Y, SPAWN_RADIUS_Y)
		
		# Calculate the final spawn coordinates relative to the SPAWNER'S center point!
		var final_spawn_position: Vector2 = global_position + Vector2(random_x, random_y)
		
		# =========================================================================
		# 🚀 EMISSION & TREE INJECTION
		# =========================================================================
		if ENEMY_SCENE:
			var enemy_instance = ENEMY_SCENE.instantiate()
			enemy_instance.global_position = final_spawn_position
			
			# Deduct from our remaining spawner pool reservoir counts
			spawn_amount -= 1
			
			# Drop the enemy directly into the main active world tree scene so pathfinding works
			get_tree().current_scene.add_child(enemy_instance)
	else:
		# If our pool reservoir hits zero, kill the timer entirely to save CPU processing power
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
