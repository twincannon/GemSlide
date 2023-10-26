extends Entity
class_name SandTrap

var moves_to_escape := 0

func _ready():
	moves = false

func _does_block(_other_entity):
	return false
	
func _on_entity_entered(_other_entity):
	_other_entity.stuck = true
	_other_entity.on_entity_pre_move.connect(pre_move)
	moves_to_escape = 2
	print("entered")
	$Fill.visible = true
	
func pre_move(entity:Entity, dir:Vector2i):
	if entity.can_move_in_dir(dir, true):
		moves_to_escape -= 1
		if moves_to_escape <= 1:
			$Fill.visible = false
		if moves_to_escape <= 0:

			entity.stuck = false
			entity.on_entity_pre_move.disconnect(pre_move)
	print(moves_to_escape)		
