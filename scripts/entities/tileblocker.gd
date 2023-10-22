extends Entity
class_name TileBlocker



# Called when the node enters the scene tree for the first time.
func _ready():
	moves = false
	entity_sprite = $TileSprite

func _does_block(_other_entity):
	return true

