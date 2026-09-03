extends Resource

class_name Inv

@export var items: Array[InvItem]
func add_item_to_storage(item: InvItem) -> bool:
	# 🔒 THE STORAGE FORCED ENTRANCE LAYER:
	# Slots 0 to 71 are for your active hands. We explicitly scan starting 
	# from slot 72 onward to guarantee picked up cards land ONLY in storage!
	for i in range(72, items.size()):
		if items[i] == null:
			items[i] = item
			return true # Item successfully tucked into the storage array!
			
	return false
