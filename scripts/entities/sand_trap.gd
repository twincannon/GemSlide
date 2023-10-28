extends Entity
class_name SandTrap

var moves_to_escape := 0
var sand_vfx_scene = preload("res://scenes/vfx/vfx_sand.tscn")

func _ready():
	moves = false

func _does_block(_other_entity):
	return false
	
func _on_entity_entered(_other_entity):
	_other_entity.stuck = true
	_other_entity.on_entity_pre_move.connect(pre_move)
	moves_to_escape = 2
	$Audio.play()
	$Fill.visible = true
	var vfx = sand_vfx_scene.instantiate()
	add_child(vfx)
	
func pre_move(entity:Entity, dir:Vector2i):
	if entity.can_move_in_dir(dir, true):
		moves_to_escape -= 1
		if moves_to_escape <= 1:
			$Fill.visible = false
		if moves_to_escape <= 0:
			entity.stuck = false
			entity.on_entity_pre_move.disconnect(pre_move)
