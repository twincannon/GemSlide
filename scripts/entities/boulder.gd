extends Entity
class_name Boulder

# Called when the node enters the scene tree for the first time.
func _ready():
	moves = false
	entity_sprite = $TileSprite

func _does_block(_other_entity):
	return true

func on_boulder_destroyed():
	$TileSprite.visible = false
	Globals.get_game_node().queue_entity_for_removal(self)
