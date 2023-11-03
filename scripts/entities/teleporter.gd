extends Entity
class_name Teleporter

var teleport_vfx_scene = preload("res://scenes/vfx/vfx_teleport.tscn")

func _ready():
	moves = false

func _does_block(_other_entity):
	return false

func _on_entity_finished_entering(_other_entity):
	var other_teleporter = null
	for e in Globals.get_game_node().entities:
		if e is Teleporter and e != self:
			other_teleporter = e
			break
	
	if !other_teleporter:
		printerr("Only one teleporter in level")
		return
	
	for e in Globals.get_game_node().get_entities_at_pos(other_teleporter.grid_pos):
		if !(e is Teleporter):
			e.teleport_to(grid_pos)
	
	var vfx = teleport_vfx_scene.instantiate()
	add_child(vfx)
	vfx = teleport_vfx_scene.instantiate()
	other_teleporter.add_child(vfx)

	$Audio.play()
	
	_other_entity.teleport_to(other_teleporter.grid_pos)
