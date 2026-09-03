extends CanvasLayer
@onready var left_hud_box: VBoxContainer = $GameplayDeckHUD/LeftHandHUD
@onready var right_hud_box: VBoxContainer = $GameplayDeckHUD/RightHandHud

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	globals.left_hand_hud_container = left_hud_box
	globals.right_hand_hud_container = right_hud_box


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if globals.player.player_is_dead:
		visible = false
	else:
		visible = true
