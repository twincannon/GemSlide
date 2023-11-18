extends Entity
class_name IceSlick

func _ready():
	moves = false

func _does_block(_other_entity):
	return false

func _on_entity_exited(_other_entity):
	_other_entity.is_forcibly_moving = false
	

func _on_entity_entered(_other_entity):
	_other_entity.is_forcibly_moving = true
	
#func _on_entity_finished_entering(_other_entity):
#	_other_entity.is_forcibly_moving = true
