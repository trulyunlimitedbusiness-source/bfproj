extends Node2D

func _ready() -> void:
	$burning.emitting = true
	# Automatically clean up the instance from memory after 0.5 seconds
	await get_tree().create_timer(0.5).timeout
	queue_free()
