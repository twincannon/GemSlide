extends Entity
class_name IceSlick

func _ready():
	moves = false
	forces_movement = true

func _does_block(_other_entity):
	return false
