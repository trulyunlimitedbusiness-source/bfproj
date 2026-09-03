extends Resource
class_name InvItem

@export var name: String = ""
@export var texture: Texture2D
@export var card_sprite_frame: int = 0

# =========================================================================
# ⚔️ THE DYNAMIC METHOD LINKER
# 💡 FIXED: This adds a text box inside your Inspector panel for every card!
# =========================================================================
@export var attack_method_name: String = ""
